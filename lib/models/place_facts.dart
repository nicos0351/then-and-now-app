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
