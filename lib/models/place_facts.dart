import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Facts about an airport, dam or mountain pass (e.g. airport codes, a
/// dam's river and capacity, a pass's height), from the bundled
/// `assets/place_facts.json` or the live data's `facts` list. Shown in the
/// place's info sheet as part of Then & Now Plus.
class PlaceFacts {
  const PlaceFacts({required this.key, required this.facts, this.sources = const []});

  /// The place's stable key (same as in the town data).
  final String key;

  /// (label, value) pairs in display order, e.g. ("River", "Vaal River").
  final List<(String, String)> facts;

  /// Where the facts come from (Wikipedia, Wikidata, OpenStreetMap).
  final List<String> sources;

  /// Throws a [FormatException] for anything that isn't a valid entry.
  factory PlaceFacts.fromJson(Map<String, dynamic> json) {
    final key = json['key'];
    final raw = json['facts'];
    if (key is! String || raw is! List || raw.isEmpty) {
      throw const FormatException('A facts entry needs a key and at least one fact.');
    }
    final facts = <(String, String)>[];
    for (final pair in raw) {
      if (pair is! List || pair.length != 2 || pair[0] is! String || pair[1] is! String) {
        throw FormatException('Facts for $key must be [label, value] pairs.');
      }
      facts.add((pair[0] as String, pair[1] as String));
    }
    final sources = (json['sources'] as List<dynamic>? ?? const []).whereType<String>().toList();
    return PlaceFacts(key: key, facts: facts, sources: sources);
  }

  /// Parses a list of entries into a map keyed by place key.
  static Map<String, PlaceFacts> parseList(List<dynamic> list) => {
        for (final e in list.cast<Map<String, dynamic>>()) e['key'] as String: PlaceFacts.fromJson(e),
      };

  /// All bundled facts, keyed by place key.
  static Future<Map<String, PlaceFacts>> loadAll() async {
    final raw = await rootBundle.loadString('assets/place_facts.json');
    return parseList(json.decode(raw) as List<dynamic>);
  }
}

/// Where a dam's weekly level is published: the Department of Water and
/// Sanitation's provincial "State of Dams" page ([region], e.g. "WC") and
/// the dam's station code on it (e.g. "H6R001"). From the data's
/// `damStations` list (bundled in `assets/dam_stations.json`).
class DamStation {
  const DamStation({required this.key, required this.region, required this.station});

  /// The dam's place key.
  final String key;
  final String region;
  final String station;

  static const regions = {'EC', 'FS', 'G', 'KN', 'LP', 'M', 'NC', 'NW', 'WC'};

  /// Throws a [FormatException] for anything that isn't a valid entry.
  factory DamStation.fromJson(Map<String, dynamic> json) {
    final key = json['key'];
    final region = json['region'];
    final station = json['station'];
    if (key is! String ||
        region is! String ||
        !regions.contains(region) ||
        station is! String ||
        !RegExp(r'^[A-Za-z0-9]{3,10}$').hasMatch(station)) {
      throw const FormatException('A dam station needs a key, a known region and a station code.');
    }
    return DamStation(key: key, region: region, station: station);
  }

  static Map<String, DamStation> parseList(List<dynamic> list) => {
        for (final e in list.cast<Map<String, dynamic>>()) e['key'] as String: DamStation.fromJson(e),
      };

  /// All bundled dam stations, keyed by dam key.
  static Future<Map<String, DamStation>> loadAll() async {
    final raw = await rootBundle.loadString('assets/dam_stations.json');
    return parseList(json.decode(raw) as List<dynamic>);
  }
}
