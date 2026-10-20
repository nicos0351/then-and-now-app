import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sa_town_names/models/map_outline.dart';
import 'package:sa_town_names/services/offline_maps_service.dart';

void main() {
  group('Map outline (no-signal fallback)', () {
    final outline = MapOutline.parse(File('assets/sa_outline.json').readAsStringSync());

    test('labels all nine provinces exactly once', () {
      final labels = outline.polygons.map((p) => p.label).whereType<String>().toList();
      expect(labels.length, 9);
      expect(labels.toSet(), {
        'Eastern Cape',
        'Free State',
        'Gauteng',
        'KwaZulu-Natal',
        'Limpopo',
        'Mpumalanga',
        'North West',
        'Northern Cape',
        'Western Cape',
      });
    });

    test('stays inside southern Africa (incl. Prince Edward Islands)', () {
      for (final polygon in outline.polygons) {
        for (final point in polygon.points) {
          expect(point.latitude, inInclusiveRange(-47.5, -15));
          expect(point.longitude, inInclusiveRange(10, 41));
        }
      }
    });
  });

  group('Offline map packs list', () {
    Map<String, dynamic> pack([Map<String, dynamic> overrides = const {}]) => {
          'id': 'sa-overview',
          'name': 'South Africa overview',
          'description': 'Whole country, zoom 5-10',
          'url': 'https://example.org/sa-overview.mbtiles',
          'sizeBytes': 120 * 1024 * 1024,
          'minZoom': 5,
          'maxZoom': 10,
          'version': 2,
          'attribution': 'OpenStreetMap contributors',
          'bounds': [16.3, -35.0, 33.0, -22.0],
          ...overrides,
        };

    String index(List<Map<String, dynamic>> packs, {int format = 1}) =>
        json.encode({'format': format, 'packs': packs});

    test('reads a valid list', () {
      final packs = OfflinePack.parseIndex(index([pack()]));
      expect(packs, hasLength(1));
      final p = packs.single;
      expect(p.id, 'sa-overview');
      expect(p.version, 2);
      expect(p.sizeLabel, '120 MB');
      expect(p.bounds, [16.3, -35.0, 33.0, -22.0]);
      expect(p.centre!.latitude, closeTo(-28.5, 0.001));
    });

    test('rejects an unknown format', () {
      expect(() => OfflinePack.parseIndex(index([pack()], format: 2)), throwsFormatException);
    });

    test('rejects plain http and odd ids', () {
      expect(() => OfflinePack.parseIndex(index([pack({'url': 'http://example.org/x.mbtiles'})])),
          throwsFormatException);
      expect(() => OfflinePack.parseIndex(index([pack({'id': '../escape'})])), throwsFormatException);
    });

    test('rejects bad size or zoom range', () {
      expect(() => OfflinePack.parseIndex(index([pack({'sizeBytes': 0})])), throwsFormatException);
      expect(() => OfflinePack.parseIndex(index([pack({'minZoom': 12, 'maxZoom': 8})])), throwsFormatException);
    });

    test('shows big packs in GB', () {
      final p = OfflinePack.fromJson(pack({'sizeBytes': 3 * 1024 * 1024 * 1024}));
      expect(p.sizeLabel, '3.0 GB');
    });
  });
}
