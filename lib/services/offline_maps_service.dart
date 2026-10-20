import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/offline_maps.dart';

/// One downloadable map pack: a raster MBTiles file covering an area at a
/// range of zoom levels (e.g. "South Africa overview, zoom 5-10" or
/// "Gauteng in detail, zoom 11-14").
class OfflinePack {
  const OfflinePack({
    required this.id,
    required this.name,
    required this.description,
    required this.url,
    required this.sizeBytes,
    required this.minZoom,
    required this.maxZoom,
    required this.version,
    required this.attribution,
    this.bounds,
  });

  /// Stable identifier, also the file name on the phone.
  final String id;
  final String name;
  final String description;

  /// Where the .mbtiles file is downloaded from (e.g. a GitHub release).
  final String url;
  final int sizeBytes;
  final int minZoom;
  final int maxZoom;

  /// Raise when the pack's file is replaced, so phones offer the update.
  final int version;

  /// Credit for the map data in the pack, shown on the map while it's used
  /// (e.g. "OpenStreetMap contributors").
  final String attribution;

  /// Area covered, as [west, south, east, north]; null = no limit.
  final List<double>? bounds;

  static final _idPattern = RegExp(r'^[a-z0-9][a-z0-9-]{0,63}$');

  factory OfflinePack.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final url = json['url'];
    if (id is! String || !_idPattern.hasMatch(id)) throw const FormatException('Bad pack id.');
    if (url is! String || !url.startsWith('https://')) throw FormatException('Pack $id needs an https URL.');
    final rawBounds = json['bounds'];
    final bounds = rawBounds is List && rawBounds.length == 4 ? [for (final b in rawBounds) (b as num).toDouble()] : null;
    final pack = OfflinePack(
      id: id,
      name: json['name'] as String? ?? id,
      description: json['description'] as String? ?? '',
      url: url,
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      minZoom: (json['minZoom'] as num?)?.toInt() ?? 0,
      maxZoom: (json['maxZoom'] as num?)?.toInt() ?? 0,
      version: (json['version'] as num?)?.toInt() ?? 1,
      attribution: json['attribution'] as String? ?? 'OpenStreetMap contributors',
      bounds: bounds,
    );
    if (pack.sizeBytes <= 0 || pack.maxZoom < pack.minZoom || pack.maxZoom > 20) {
      throw FormatException('Pack $id has a bad size or zoom range.');
    }
    return pack;
  }

  /// Parses the packs list (`packs.json`).
  static List<OfflinePack> parseIndex(String body) {
    final decoded = json.decode(body);
    if (decoded is! Map<String, dynamic> || decoded['format'] != 1 || decoded['packs'] is! List) {
      throw const FormatException('The map packs list has the wrong format.');
    }
    return [for (final p in (decoded['packs'] as List).cast<Map<String, dynamic>>()) OfflinePack.fromJson(p)];
  }

  String get sizeLabel {
    final mb = sizeBytes / (1024 * 1024);
    return mb >= 1024 ? '${(mb / 1024).toStringAsFixed(1)} GB' : '${mb.round()} MB';
  }

  LatLng? get centre => bounds == null ? null : LatLng((bounds![1] + bounds![3]) / 2, (bounds![0] + bounds![2]) / 2);
}

/// A pack that's on this phone.
class InstalledPack {
  const InstalledPack({required this.pack, required this.path});
  final OfflinePack pack;
  final String path;
}

/// Downloads, stores and removes map packs, and remembers whether the map
/// should use them. Packs live in the app's private storage; removing the
/// app removes them.
class OfflineMapsService {
  OfflineMapsService._();
  static final OfflineMapsService instance = OfflineMapsService._();

  static const _installedKey = 'offline_packs_installed'; // JSON list of pack JSON
  static const _useOfflineKey = 'offline_maps_in_use';

  /// Bumped whenever packs are added/removed or the setting changes, so
  /// the map can rebuild its layers.
  final ValueNotifier<int> changes = ValueNotifier<int>(0);

  Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/offline_maps');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Downloads the list of available packs.
  Future<List<OfflinePack>> fetchAvailable() async {
    final response = await http.get(Uri.parse(kOfflinePacksUrl)).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw HttpException('The map packs list is not available (${response.statusCode}).');
    }
    return OfflinePack.parseIndex(utf8.decode(response.bodyBytes));
  }

  /// Packs on this phone (whose files still exist).
  Future<List<InstalledPack>> installed() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_installedKey);
    if (raw == null) return const [];
    final dir = await _dir();
    final result = <InstalledPack>[];
    try {
      for (final p in (json.decode(raw) as List).cast<Map<String, dynamic>>()) {
        final pack = OfflinePack.fromJson(p);
        final path = '${dir.path}/${pack.id}.mbtiles';
        if (await File(path).exists()) result.add(InstalledPack(pack: pack, path: path));
      }
    } catch (e) {
      debugPrint('Ignoring broken offline pack list: $e');
    }
    // Overview (low zoom) packs first, so detailed packs draw on top.
    result.sort((a, b) => a.pack.maxZoom.compareTo(b.pack.maxZoom));
    return result;
  }

  Future<bool> useOffline() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_useOfflineKey) ?? true;
  }

  Future<void> setUseOffline(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useOfflineKey, value);
    changes.value++;
  }

  /// Downloads [pack], reporting progress (0..1). Downloads to a temporary
  /// file first and only replaces the installed pack once the whole file
  /// has arrived with the expected size.
  Future<void> download(OfflinePack pack, {void Function(double progress)? onProgress}) async {
    final dir = await _dir();
    final target = File('${dir.path}/${pack.id}.mbtiles');
    final partial = File('${dir.path}/${pack.id}.mbtiles.part');
    final client = http.Client();
    try {
      final response = await client.send(http.Request('GET', Uri.parse(pack.url)));
      if (response.statusCode != 200) {
        throw HttpException('Download failed (${response.statusCode}).');
      }
      final total = response.contentLength ?? pack.sizeBytes;
      var received = 0;
      final sink = partial.openWrite();
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) onProgress?.call((received / total).clamp(0.0, 1.0).toDouble());
        }
      } finally {
        await sink.close();
      }
      if (received != pack.sizeBytes) {
        throw HttpException('The download was incomplete ($received of ${pack.sizeBytes} bytes).');
      }
      if (await target.exists()) await target.delete();
      await partial.rename(target.path);
      await _excludeFromBackup(target.path);
      await _remember(pack);
      changes.value++;
    } catch (_) {
      if (await partial.exists()) await partial.delete();
      rethrow;
    } finally {
      client.close();
    }
  }

  static const _platform = MethodChannel('then_and_now/files');

  /// iOS backs up the app's support folder to iCloud, and Apple rejects
  /// apps that back up large re-downloadable files. This asks the iOS side
  /// (a few lines in AppDelegate - see README, "Offline Maps add-on") to
  /// exclude the pack from backups. Android doesn't back up this folder's
  /// large files by default, so nothing is needed there.
  Future<void> _excludeFromBackup(String path) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await _platform.invokeMethod<void>('excludeFromBackup', {'path': path});
    } on MissingPluginException {
      debugPrint('excludeFromBackup is not set up in AppDelegate - see README.');
    } on PlatformException catch (e) {
      debugPrint('Could not exclude $path from backup: ${e.message}');
    }
  }

  Future<void> remove(String packId) async {
    final dir = await _dir();
    final file = File('${dir.path}/$packId.mbtiles');
    if (await file.exists()) await file.delete();
    final prefs = await SharedPreferences.getInstance();
    final list = _storedList(prefs)..removeWhere((p) => p['id'] == packId);
    await prefs.setString(_installedKey, json.encode(list));
    changes.value++;
  }

  Future<void> _remember(OfflinePack pack) async {
    final prefs = await SharedPreferences.getInstance();
    final list = _storedList(prefs)..removeWhere((p) => p['id'] == pack.id);
    list.add({
      'id': pack.id,
      'name': pack.name,
      'description': pack.description,
      'url': pack.url,
      'sizeBytes': pack.sizeBytes,
      'minZoom': pack.minZoom,
      'maxZoom': pack.maxZoom,
      'version': pack.version,
      'attribution': pack.attribution,
      if (pack.bounds != null) 'bounds': pack.bounds,
    });
    await prefs.setString(_installedKey, json.encode(list));
  }

  List<Map<String, dynamic>> _storedList(SharedPreferences prefs) {
    final raw = prefs.getString(_installedKey);
    if (raw == null) return [];
    try {
      return (json.decode(raw) as List).cast<Map<String, dynamic>>().toList();
    } catch (_) {
      return [];
    }
  }
}
