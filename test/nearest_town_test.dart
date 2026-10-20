import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sa_town_names/models/town.dart';
import 'package:sa_town_names/utils/nearest_town.dart';

void main() {
  final towns = (json.decode(File('assets/towns.json').readAsStringSync()) as List)
      .map((e) => Town.fromJson(e as Map<String, dynamic>))
      .toList();

  test('standing in a renamed town shows its old name', () {
    final result = findWhereAmI(towns, -25.48, 30.97)!; // central Mbombela
    expect(result.proximity, Proximity.inTown);
    expect(result.nearest.town.currentName, 'Mbombela');
    expect(result.nearest.town.oldName, 'Nelspruit');
    // The town itself is renamed, so no extra suggestion is needed.
    expect(result.nearestRenamed, isNull);
  });

  test('in a town with no rename, the nearest renamed town is suggested', () {
    final result = findWhereAmI(towns, -25.33177, 31.01166)!; // White River
    expect(result.nearest.town.currentName, 'White River');
    expect(result.nearestRenamed?.town.currentName, 'Mbombela');
    expect(result.nearestRenamed!.distanceKm, closeTo(16.5, 0.5));
  });

  test('far outside the country is recognised', () {
    final result = findWhereAmI(towns, -40, 10)!; // South Atlantic
    expect(result.proximity, Proximity.outsideSouthAfrica);
    expect(result.nearestRenamed, isNull);
  });

  test('no towns gives no answer', () {
    expect(findWhereAmI(const [], -26, 28), isNull);
  });

  test('distances are formatted for people', () {
    expect(formatDistance(0.01), '50 m');
    expect(formatDistance(0.42), '400 m');
    expect(formatDistance(3), '3 km');
    expect(formatDistance(3.46), '3.5 km');
    expect(formatDistance(16.5), '17 km');
  });
}
