import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/place_facts.dart';

/// The Department of Water and Sanitation's weekly "State of Dams" page
/// for one province (region codes EC FS G KN LP M NC NW WC).
String dwsPageUrl(String region) => 'https://www.dws.gov.za/Hydrology/Weekly/ProvinceWeek.aspx?region=$region';

/// One weekly figure: percent full, and whether it's the "latest available"
/// figure rather than this week's (the page marks those with #).
class DamReading {
  const DamReading(this.percent, {this.latestAvailable = false});
  final double percent;
  final bool latestAvailable;

  /// e.g. "74.7%".
  String get label => '${percent.toStringAsFixed(1)}%';
}

/// A dam's row on the weekly page.
class DamLevel {
  const DamLevel({
    required this.station,
    required this.name,
    this.capacityMcm,
    this.thisWeek,
    this.lastWeek,
    this.lastYear,
    this.reportDate,
  });

  final String station;
  final String name;

  /// Full storage capacity in million cubic metres.
  final double? capacityMcm;
  final DamReading? thisWeek;
  final DamReading? lastWeek;
  final DamReading? lastYear;

  /// The date in the page's title ("... State of Dams on 2026-10-12").
  final DateTime? reportDate;
}

final _title = RegExp(r'State of Dams on (\d{4})-(\d{2})-(\d{2})');
final _row = RegExp(r'<tr[^>]*>(.*?)</tr>', dotAll: true);
final _cell = RegExp(r'<td[^>]*>(.*?)</td>', dotAll: true);
final _station = RegExp(r'percentile\.aspx\?station=(?:%20|\s)*([A-Za-z0-9]+)');
final _tags = RegExp(r'<[^>]+>');

DamReading? _reading(String cell) {
  final text = cell.trim();
  final latest = text.startsWith('#');
  final value = double.tryParse(text.replaceAll('#', '').trim());
  return value == null ? null : DamReading(value, latestAvailable: latest);
}

/// Reads every dam row of a weekly provincial page, keyed by station code.
/// Rows it can't make sense of are skipped, so a small change to the page
/// loses at most those rows.
Map<String, DamLevel> parseDwsPage(String html) {
  final t = _title.firstMatch(html);
  final date = t == null ? null : DateTime(int.parse(t.group(1)!), int.parse(t.group(2)!), int.parse(t.group(3)!));
  final levels = <String, DamLevel>{};
  for (final row in _row.allMatches(html)) {
    final body = row.group(1)!;
    final station = _station.firstMatch(body)?.group(1);
    final cells = _cell.allMatches(body).map((m) => m.group(1)!.replaceAll(_tags, '').trim()).toList();
    if (station == null || cells.length != 8) continue;
    levels[station] = DamLevel(
      station: station,
      name: cells[0],
      capacityMcm: double.tryParse(cells[4]),
      thisWeek: _reading(cells[5]),
      lastWeek: _reading(cells[6]),
      lastYear: _reading(cells[7]),
      reportDate: date,
    );
  }
  return levels;
}

/// Why a level couldn't be shown.
enum DamLevelProblem { offline, notListed }

class DamLevelResult {
  const DamLevelResult.found(this.level, {this.fromCache = false}) : problem = null;
  const DamLevelResult.failed(this.problem)
      : level = null,
        fromCache = false;

  final DamLevel? level;
  final DamLevelProblem? problem;

  /// True when the site couldn't be reached and an older saved copy was used.
  final bool fromCache;
}

/// Gets a dam's weekly level straight from the department's website, on
/// the phone (the site doesn't answer servers abroad). Each province's page
/// is downloaded at most every few hours and kept on the phone, so an older
/// copy can still be shown without a connection.
class DamLevelsService {
  DamLevelsService._();
  static final DamLevelsService instance = DamLevelsService._();

  static const _freshFor = Duration(hours: 6);
  final _memory = <String, (DateTime, Map<String, DamLevel>)>{};
  final _inFlight = <String, Future<Map<String, DamLevel>?>>{};

  Future<File> _file(String region) async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/dws_$region.html');
  }

  Future<DamLevelResult> levelFor(DamStation station) async {
    final region = station.region;
    final cached = _memory[region];
    if (cached != null && DateTime.now().difference(cached.$1) < _freshFor) {
      return _pick(cached.$2, station);
    }
    // Fresh copy on disk?
    try {
      final file = await _file(region);
      if (await file.exists() && DateTime.now().difference(await file.lastModified()) < _freshFor) {
        final levels = parseDwsPage(await file.readAsString());
        _memory[region] = (await file.lastModified(), levels);
        return _pick(levels, station);
      }
    } catch (e) {
      debugPrint('Ignoring saved dam levels: $e');
    }
    final downloaded = await (_inFlight[region] ??= _download(region).whenComplete(() => _inFlight.remove(region)));
    if (downloaded != null) return _pick(downloaded, station);
    // No connection: fall back to the last saved copy, however old.
    try {
      final file = await _file(region);
      if (await file.exists()) {
        final level = parseDwsPage(await file.readAsString())[station.station];
        if (level != null) return DamLevelResult.found(level, fromCache: true);
      }
    } catch (_) {}
    return const DamLevelResult.failed(DamLevelProblem.offline);
  }

  DamLevelResult _pick(Map<String, DamLevel> levels, DamStation station) {
    final level = levels[station.station];
    return level == null ? const DamLevelResult.failed(DamLevelProblem.notListed) : DamLevelResult.found(level);
  }

  Future<Map<String, DamLevel>?> _download(String region) async {
    try {
      final response = await http.get(Uri.parse(dwsPageUrl(region)), headers: const {
        'User-Agent': 'ThenAndNow-SA-Town-Names (Android app; thenandnow0351@gmail.com)',
      }).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      final html = utf8.decode(response.bodyBytes, allowMalformed: true);
      final levels = parseDwsPage(html);
      if (levels.isEmpty) return null; // not the page we expected
      _memory[region] = (DateTime.now(), levels);
      try {
        await (await _file(region)).writeAsString(html, flush: true);
      } catch (_) {}
      return levels;
    } catch (e) {
      debugPrint('Could not download dam levels for $region: $e');
      return null;
    }
  }
}
