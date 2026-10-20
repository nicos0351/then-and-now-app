import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/name_story.dart';
import '../models/town.dart';
import '../utils/provinces.dart';
import 'database_helper.dart';

/// Where the live town data is published (GitHub Pages of the
/// `then-and-now-data` repository). See that repository's README for how
/// to publish an update.
const String kRemoteDataUrl = 'https://nicos0351.github.io/then-and-now-data/data.json';

/// The only `format` this app version understands. A future file layout
/// would use a new number, and older apps would simply ignore it.
const int kRemoteDataFormat = 1;

/// A downloaded file with fewer towns than this is assumed broken.
const int kMinRemoteTowns = 900;

/// One entry of the file's "What's new" list.
class DataChange {
  const DataChange(this.version, this.date, this.summary);
  final int version;
  final String date;
  final String summary;
}

/// A downloaded and fully checked `data.json`.
class RemotePayload {
  const RemotePayload({
    required this.dataVersion,
    required this.updated,
    required this.changes,
    required this.towns,
    required this.storiesJson,
  });

  final int dataVersion;
  final String updated;
  final List<DataChange> changes;
  final List<Town> towns;

  /// The raw `stories` list, cached to disk as-is.
  final List<dynamic> storiesJson;

  static dynamic _decode(String body) {
    try {
      return json.decode(body);
    } catch (_) {
      throw const FormatException('The update file is not valid JSON.');
    }
  }

  static Town _town(dynamic raw) {
    try {
      return Town.fromJson(raw as Map<String, dynamic>);
    } catch (_) {
      throw const FormatException('The update file has a town with missing or wrong fields.');
    }
  }

  /// Parses and checks [body]. Throws a [FormatException] saying what's
  /// wrong if anything looks off, so a broken file is never applied.
  static RemotePayload parse(String body) {
    final decoded = _decode(body);
    if (decoded is! Map<String, dynamic>) throw const FormatException('The update file has the wrong layout.');
    if (decoded['format'] != kRemoteDataFormat) {
      throw const FormatException('The update file needs a newer version of the app.');
    }
    final version = decoded['dataVersion'];
    if (version is! int || version < 1) throw const FormatException('The update file has no valid dataVersion.');

    final rawTowns = decoded['towns'];
    if (rawTowns is! List || rawTowns.length < kMinRemoteTowns) {
      throw const FormatException('The update file has too few towns.');
    }
    final towns = <Town>[];
    final keys = <String>{};
    for (final raw in rawTowns) {
      final town = _town(raw);
      final key = town.sourceKey;
      if (key == null || !key.startsWith('asset:') || !keys.add(key)) {
        throw FormatException('Bad or duplicate key for ${town.currentName}.');
      }
      if (!const {'town', 'airport', 'dam', 'pass'}.contains(town.kind)) {
        throw FormatException('Unknown place type for ${town.currentName}.');
      }
      if (!saProvinces.contains(town.province)) {
        throw FormatException('Unknown province for ${town.currentName}.');
      }
      if (town.latitude <= -35.5 || town.latitude >= -22 || town.longitude <= 16 || town.longitude >= 33.5) {
        throw FormatException('${town.currentName} is outside South Africa.');
      }
      towns.add(town);
    }

    final rawStories = decoded['stories'] ?? const [];
    if (rawStories is! List) throw const FormatException('The update file has a broken stories list.');
    for (final raw in rawStories) {
      try {
        NameStory.fromJson(raw as Map<String, dynamic>);
      } catch (_) {
        throw const FormatException('The update file has a broken name story.');
      }
    }

    final changes = <DataChange>[];
    for (final raw in (decoded['changes'] as List<dynamic>? ?? const [])) {
      if (raw is Map<String, dynamic> && raw['version'] is int && raw['summary'] is String) {
        changes.add(DataChange(raw['version'] as int, raw['date'] as String? ?? '', raw['summary'] as String));
      }
    }

    return RemotePayload(
      dataVersion: version,
      updated: decoded['updated'] as String? ?? '',
      changes: changes,
      towns: towns,
      storiesJson: rawStories,
    );
  }
}

enum RefreshStatus { updated, upToDate, failed }

class RefreshResult {
  const RefreshResult(this.status, {this.version, this.changes = const [], this.message});
  final RefreshStatus status;

  /// The data version the phone has after the refresh.
  final int? version;

  /// "What's new" summaries for the versions just installed.
  final List<String> changes;

  /// Why it failed, in plain words.
  final String? message;
}

/// Downloads the live town data and applies it when it's newer than what
/// the phone has. The bundled data keeps working without a connection;
/// this only ever adds newer data on top.
class RemoteDataService {
  RemoteDataService._();
  static final RemoteDataService instance = RemoteDataService._();

  /// How often the app checks on its own (on opening the map).
  static const Duration autoCheckInterval = Duration(days: 7);

  static const _lastCheckKey = 'remote_data_last_check_ms';
  static const _storiesFile = 'remote_stories.json';

  bool _busy = false;

  /// Downloads, checks and (if newer) applies the live data.
  Future<RefreshResult> refresh() async {
    if (_busy) return const RefreshResult(RefreshStatus.failed, message: 'An update check is already running.');
    _busy = true;
    try {
      final response = await http
          .get(Uri.parse(kRemoteDataUrl), headers: const {'Cache-Control': 'no-cache'})
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        return RefreshResult(RefreshStatus.failed,
            message: 'The update server answered with an error (${response.statusCode}). Please try again later.');
      }
      // Checked in the background: it's a large file, and parsing it on the
      // main thread would make the map stutter on slower phones.
      final body = utf8.decode(response.bodyBytes);
      final payload = await Isolate.run(() => RemotePayload.parse(body));
      await _recordCheck();

      final db = DatabaseHelper.instance;
      final local = await db.dataVersion();
      if (payload.dataVersion <= local) {
        return RefreshResult(RefreshStatus.upToDate, version: local);
      }

      await db.applyTownData(payload.towns, payload.dataVersion);
      await _saveStories(payload.dataVersion, payload.storiesJson);
      final news = payload.changes.where((c) => c.version > local).toList()
        ..sort((a, b) => a.version.compareTo(b.version));
      return RefreshResult(
        RefreshStatus.updated,
        version: payload.dataVersion,
        changes: news.map((c) => c.summary).toList(),
      );
    } on TimeoutException {
      return const RefreshResult(RefreshStatus.failed,
          message: 'The update server took too long to answer. Check your connection and try again.');
    } on SocketException {
      return const RefreshResult(RefreshStatus.failed,
          message: "Couldn't connect to check for updates. Check your internet connection.");
    } on http.ClientException {
      // package:http reports most network failures this way.
      return const RefreshResult(RefreshStatus.failed,
          message: "Couldn't connect to check for updates. Check your internet connection.");
    } on FormatException catch (e) {
      debugPrint('Rejected update file: ${e.message}');
      return const RefreshResult(RefreshStatus.failed,
          message: "The update file couldn't be used, so your current town names were kept. "
              'Please try again later.');
    } catch (e) {
      debugPrint('Update check failed: $e');
      return const RefreshResult(RefreshStatus.failed, message: 'Something went wrong checking for updates.');
    } finally {
      _busy = false;
    }
  }

  /// Checks on its own at most once per [autoCheckInterval]. Returns the
  /// result only when something was actually updated (failures and "no
  /// news" stay silent), otherwise null.
  Future<RefreshResult?> autoRefreshIfDue() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_lastCheckKey);
    if (last != null &&
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(last)) < autoCheckInterval) {
      return null;
    }
    final result = await refresh();
    return result.status == RefreshStatus.updated ? result : null;
  }

  /// When the town data was last successfully refreshed (a check that
  /// reached the server and read a valid file, whether or not anything
  /// was new), or null if that has never happened on this phone.
  Future<DateTime?> lastRefreshed() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_lastCheckKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> _recordCheck() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<File> _storiesPath() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_storiesFile');
  }

  Future<void> _saveStories(int version, List<dynamic> stories) async {
    final file = await _storiesPath();
    await file.writeAsString(json.encode({'dataVersion': version, 'stories': stories}), flush: true);
  }

  /// Name stories from the last downloaded update, if they're newer than
  /// the ones bundled with this app version; otherwise null (use the
  /// bundled ones).
  Future<Map<String, NameStory>?> cachedStoriesIfNewer() async {
    try {
      final file = await _storiesPath();
      if (!await file.exists()) return null;
      final decoded = json.decode(await file.readAsString()) as Map<String, dynamic>;
      final version = decoded['dataVersion'] as int? ?? 0;
      if (version <= DatabaseHelper.seedVersion) return null;
      final list = (decoded['stories'] as List<dynamic>).cast<Map<String, dynamic>>();
      return {for (final e in list) e['key'] as String: NameStory.fromJson(e)};
    } catch (e) {
      debugPrint('Ignoring cached stories: $e');
      return null;
    }
  }
}
