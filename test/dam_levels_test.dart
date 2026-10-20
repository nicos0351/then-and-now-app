import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sa_town_names/models/place_facts.dart';
import 'package:sa_town_names/models/town.dart';
import 'package:sa_town_names/services/dam_levels_service.dart';

void main() {
  group('Weekly State of Dams page', () {
    // Saved from www.dws.gov.za on 20 Oct 2026 (report of 12 Oct 2026).
    final wc = parseDwsPage(File('test/fixtures/dws_wc.html').readAsStringSync());
    final nc = parseDwsPage(File('test/fixtures/dws_nc.html').readAsStringSync());

    test('reads every dam row, but not the total', () {
      expect(wc, hasLength(47));
      expect(nc, hasLength(6));
    });

    test('reads a dam by its station code', () {
      final t = wc['H6R001']!;
      expect(t.name, 'Theewaterskloof Dam');
      expect(t.capacityMcm, 479.3);
      expect(t.thisWeek!.percent, 74.7);
      expect(t.lastWeek!.percent, 75.0);
      expect(t.lastYear!.percent, 84.5);
      expect(t.thisWeek!.latestAvailable, isFalse);
      expect(t.reportDate, DateTime(2026, 10, 12));
      expect(t.thisWeek!.label, '74.7%');
    });

    test('marks figures that are only the latest available (#)', () {
      final leeubos = nc['D4R001']!;
      expect(leeubos.thisWeek!.latestAvailable, isTrue);
      expect(leeubos.thisWeek!.percent, 0.0);
    });

    test('a page that is not the report gives nothing', () {
      expect(parseDwsPage('<html><body>Invalid Province</body></html>'), isEmpty);
    });
  });

  group('Bundled dam stations', () {
    final places = (json.decode(File('assets/towns.json').readAsStringSync()) as List)
        .map((e) => Town.fromJson(e as Map<String, dynamic>))
        .toList();
    final byKey = {for (final t in places) t.sourceKey: t};
    final stations = DamStation.parseList(json.decode(File('assets/dam_stations.json').readAsStringSync()) as List);

    test('each station belongs to a dam on the map', () {
      expect(stations.length, greaterThan(150));
      for (final s in stations.values) {
        expect(byKey[s.key]?.kind, 'dam', reason: s.key);
      }
    });

    test('the Theewaterskloof Dam station is the one on the Western Cape page', () {
      final dam = places.singleWhere((t) => t.currentName == 'Theewaterskloof Dam');
      final s = stations[dam.sourceKey]!;
      expect(s.region, 'WC');
      expect(s.station, 'H6R001');
    });

    test('bad entries are rejected', () {
      expect(() => DamStation.fromJson({'key': 'asset:x', 'region': 'XX', 'station': 'H6R001'}), throwsFormatException);
      expect(() => DamStation.fromJson({'key': 'asset:x', 'region': 'WC', 'station': '<script>'}), throwsFormatException);
    });
  });
}
