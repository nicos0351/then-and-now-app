import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/services.dart' show rootBundle;

import '../models/town.dart';

/// Loads the full, nationwide town dataset bundled at
/// `assets/towns.json`. This ships ~1,000 South African towns sourced
/// from GeoNames (https://www.geonames.org, CC BY 4.0), merged with a
/// hand-curated set of documented previous renames for the
/// towns that have them (see README for details and how to extend it).
class TownAssetLoader {
  static Future<List<Town>> loadAll() async {
    final raw = await rootBundle.loadString('assets/towns.json');
    // Decoding ~1,000 towns takes a noticeable moment on entry-level
    // phones, so it runs in the background instead of freezing the screen.
    return Isolate.run(() => parse(raw));
  }

  static List<Town> parse(String raw) {
    final List<dynamic> decoded = json.decode(raw) as List<dynamic>;
    return decoded
        .map((e) => Town.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
