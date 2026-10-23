import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What a check for a new version found.
enum UpdateCheckOutcome {
  /// This is the newest version on Google Play.
  upToDate,

  /// A newer version is downloading (Google Play asked the person first).
  downloading,

  /// A newer version has downloaded and only needs a restart.
  readyToInstall,

  /// The person said no in Google Play's box.
  declined,

  /// This copy wasn't installed from Google Play (e.g. built on the PC),
  /// so Google Play can't update it.
  notFromPlay,

  /// Not an Android phone.
  notAndroid,

  /// Google Play couldn't be asked (no connection, Play Store busy...).
  failed,
}

/// Offers a newer version from Google Play inside the app ("in-app
/// updates"): Google Play shows its own "Update available" box, the update
/// downloads in the background while the app is used, and a message then
/// offers to restart into the new version.
///
/// Checked by itself when the app opens and when it comes back after an
/// hour or more (asking at most once a day), and on request from the menu
/// ("Check for updates"), which always asks and says what it found.
///
/// Only works for copies installed from Google Play. Google Play's own
/// record of new versions can lag a few hours behind a release; opening
/// the Play Store refreshes it.
class AppUpdateService {
  AppUpdateService._();

  static const _lastAskedKey = 'app_update_last_asked_ms';
  static const _askEvery = Duration(days: 1);
  static const _checkEvery = Duration(hours: 1);
  static DateTime? _lastChecked;
  static bool _busy = false;

  /// The automatic check: quiet unless there's an update to offer.
  static Future<void> checkForUpdate(ScaffoldMessengerState messenger) async {
    if (kIsWeb || !Platform.isAndroid || kDebugMode || _busy) return;
    final now = DateTime.now();
    if (_lastChecked != null && now.difference(_lastChecked!) < _checkEvery) return;
    _lastChecked = now;
    await _check(messenger, manual: false);
  }

  /// "Check for updates" in the menu: always asks Google Play, and returns
  /// what it found so the screen can say so.
  static Future<UpdateCheckOutcome> checkNow(ScaffoldMessengerState messenger) async {
    if (kIsWeb || !Platform.isAndroid) return UpdateCheckOutcome.notAndroid;
    if (_busy) return UpdateCheckOutcome.downloading;
    _lastChecked = DateTime.now();
    return _check(messenger, manual: true);
  }

  static Future<UpdateCheckOutcome> _check(ScaffoldMessengerState messenger, {required bool manual}) async {
    _busy = true;
    try {
      final info = await InAppUpdate.checkForUpdate();

      // Downloaded earlier but not installed yet: just offer the restart.
      if (info.installStatus == InstallStatus.downloaded) {
        _offerRestart(messenger);
        return UpdateCheckOutcome.readyToInstall;
      }
      if (info.installStatus == InstallStatus.downloading || info.installStatus == InstallStatus.pending) {
        return UpdateCheckOutcome.downloading;
      }
      if (info.updateAvailability != UpdateAvailability.updateAvailable) return UpdateCheckOutcome.upToDate;

      final prefs = await SharedPreferences.getInstance();
      if (!manual) {
        final last = prefs.getInt(_lastAskedKey);
        if (last != null && DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(last)) < _askEvery) {
          return UpdateCheckOutcome.declined;
        }
      }
      await prefs.setInt(_lastAskedKey, DateTime.now().millisecondsSinceEpoch);

      if (!info.flexibleUpdateAllowed) {
        // Only the full-screen kind is allowed: Google Play installs and
        // restarts by itself.
        if (!info.immediateUpdateAllowed) return UpdateCheckOutcome.failed;
        final result = await InAppUpdate.performImmediateUpdate();
        return result == AppUpdateResult.success ? UpdateCheckOutcome.readyToInstall : UpdateCheckOutcome.declined;
      }

      // Google Play asks the person; this completes once the download is done.
      final result = await InAppUpdate.startFlexibleUpdate();
      if (result == AppUpdateResult.success) {
        _offerRestart(messenger);
        return UpdateCheckOutcome.readyToInstall;
      }
      return result == AppUpdateResult.userDeniedUpdate ? UpdateCheckOutcome.declined : UpdateCheckOutcome.failed;
    } on PlatformException catch (e) {
      debugPrint('In-app update check: $e');
      return isNotFromPlayError(e.message) ? UpdateCheckOutcome.notFromPlay : UpdateCheckOutcome.failed;
    } catch (e) {
      debugPrint('In-app update check: $e');
      return UpdateCheckOutcome.failed;
    } finally {
      _busy = false;
    }
  }

  /// Google Play's "Install Error(-10): The app is not owned by any user on
  /// this device" (or -6, "not allowed"): the copy didn't come from Google
  /// Play for this person.
  @visibleForTesting
  static bool isNotFromPlayError(String? message) {
    final m = (message ?? '').toLowerCase();
    return m.contains('(-10)') || m.contains('not owned') || m.contains('(-6)');
  }

  /// What to tell the person after "Check for updates", or null when
  /// Google Play's own box or the restart message already says it.
  static String? messageFor(UpdateCheckOutcome outcome) => switch (outcome) {
        UpdateCheckOutcome.upToDate => "You have the latest version. (If you've just been told about a new "
            'one, open the Play Store app once and try again in a few minutes.)',
        UpdateCheckOutcome.downloading => 'The new version is downloading. A message will offer a restart when it\'s ready.',
        UpdateCheckOutcome.readyToInstall => null,
        UpdateCheckOutcome.declined => 'Update not installed. You can update any time from the Play Store.',
        UpdateCheckOutcome.notFromPlay => "Couldn't check: this copy wasn't installed from Google Play. "
            'Uninstall it and install it from Google Play to get updates.',
        UpdateCheckOutcome.notAndroid => 'Updates come from the App Store.',
        UpdateCheckOutcome.failed => "Couldn't reach Google Play. Check your connection and try again.",
      };

  static void _offerRestart(ScaffoldMessengerState messenger) {
    messenger.showSnackBar(
      SnackBar(
        content: const Text('The new version of Then & Now is ready.'),
        duration: const Duration(days: 1), // stays until tapped or swiped away
        action: SnackBarAction(
          label: 'Restart',
          onPressed: () async {
            try {
              await InAppUpdate.completeFlexibleUpdate();
            } catch (e) {
              debugPrint('Could not finish the update: $e');
            }
          },
        ),
      ),
    );
  }
}
