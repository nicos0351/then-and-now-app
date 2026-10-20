import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Offers a newer version from Google Play inside the app ("in-app
/// updates"): Google Play shows its own "Update available" box, the update
/// downloads in the background while the app is used, and a message then
/// offers to restart into the new version.
///
/// Only works for copies installed from Google Play (not test builds run
/// from a computer), and asks at most once a day.
class AppUpdateService {
  AppUpdateService._();

  static const _lastAskedKey = 'app_update_last_asked_ms';
  static const _askEvery = Duration(days: 1);
  static bool _checkedThisRun = false;

  static Future<void> checkForUpdate(ScaffoldMessengerState messenger) async {
    if (_checkedThisRun || kIsWeb || !Platform.isAndroid || kDebugMode) return;
    _checkedThisRun = true;
    try {
      final info = await InAppUpdate.checkForUpdate();

      // Downloaded earlier but not installed yet: just offer the restart.
      if (info.installStatus == InstallStatus.downloaded) {
        _offerRestart(messenger);
        return;
      }
      if (info.updateAvailability != UpdateAvailability.updateAvailable || !info.flexibleUpdateAllowed) return;

      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt(_lastAskedKey);
      if (last != null && DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(last)) < _askEvery) return;
      await prefs.setInt(_lastAskedKey, DateTime.now().millisecondsSinceEpoch);

      // Google Play asks the person; this completes once the download is done.
      final result = await InAppUpdate.startFlexibleUpdate();
      if (result == AppUpdateResult.success) _offerRestart(messenger);
    } catch (e) {
      // Not installed from Google Play, no connection, Play Store busy...
      // nothing to tell the person.
      debugPrint('In-app update check skipped: $e');
    }
  }

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
