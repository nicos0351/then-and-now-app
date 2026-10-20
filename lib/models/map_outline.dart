import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// A simple, bundled outline of South Africa's provinces and its
/// neighbours (Natural Earth, public domain - see assets/sa_outline.json).
///
/// It's drawn *underneath* the map tiles, so normally you never see it.
/// Where tiles can't load (no signal, an area never viewed before), the
/// country's shape and province borders show through instead of a blank
/// grey screen, with the town pins on top.
class MapOutline {
  const MapOutline(this.polygons);

  final List<Polygon> polygons;

  static const _provinceFill = Color(0xFFFAF6E8);
  static const _provinceBorder = Color(0xFF9C7A5B);
  static const _neighbourFill = Color(0xFFECECE6);
  static const _neighbourBorder = Color(0xFFB0B0B0);

  /// Sea colour, used as the map's background.
  static const seaColour = Color(0xFFD6E6F0);

  static Future<MapOutline> load() async {
    final raw = await rootBundle.loadString('assets/sa_outline.json');
    return parse(raw);
  }

  /// Parses the asset (separate from [load] so tests can use it).
  static MapOutline parse(String raw) {
    final data = json.decode(raw) as Map<String, dynamic>;
    final polygons = <Polygon>[];

    void addFeatures(String group, Color fill, Color border, {required bool labelled}) {
      for (final feature in (data[group] as List<dynamic>).cast<Map<String, dynamic>>()) {
        final parts = (feature['polygons'] as List<dynamic>).cast<Map<String, dynamic>>();
        // Label only the largest part of each province (by point count).
        var largest = 0;
        for (var i = 1; i < parts.length; i++) {
          if ((parts[i]['outer'] as List).length > (parts[largest]['outer'] as List).length) largest = i;
        }
        for (var i = 0; i < parts.length; i++) {
          final part = parts[i];
          polygons.add(Polygon(
            points: _ring(part['outer'] as List<dynamic>),
            holePointsList: [for (final h in (part['holes'] as List<dynamic>)) _ring(h as List<dynamic>)],
            color: fill,
            borderColor: border,
            borderStrokeWidth: 1,
            label: labelled && i == largest ? feature['name'] as String : null,
            labelStyle: const TextStyle(fontSize: 11, color: Color(0xFF8A7A66), fontWeight: FontWeight.w600),
          ));
        }
      }
    }

    // Neighbours first so provinces draw on top of them.
    addFeatures('neighbours', _neighbourFill, _neighbourBorder, labelled: false);
    addFeatures('provinces', _provinceFill, _provinceBorder, labelled: true);
    return MapOutline(polygons);
  }

  static List<LatLng> _ring(List<dynamic> coords) => [
        for (final c in coords)
          LatLng(((c as List<dynamic>)[1] as num).toDouble(), (c[0] as num).toDouble()),
      ];
}
