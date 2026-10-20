import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sa_town_names/models/town.dart';
import 'package:sa_town_names/screens/map_screen.dart';

void main() {
  final places = (json.decode(File('assets/towns.json').readAsStringSync()) as List)
      .map((e) => Town.fromJson(e as Map<String, dynamic>))
      .toList();

  test('"Show all" keeps every place', () {
    expect(places.where(PlaceFilter.all.includes).length, places.length);
  });

  test('each type filter shows only that kind, and together they cover every place', () {
    var total = 0;
    for (final filter in PlaceFilter.values.where((f) => f != PlaceFilter.all)) {
      final shown = places.where(filter.includes).toList();
      expect(shown, isNotEmpty, reason: filter.name);
      total += shown.length;
    }
    expect(total, places.length);
    expect(places.where(PlaceFilter.airports.includes).every((t) => t.kindLabel == 'Airport'), isTrue);
    expect(places.where(PlaceFilter.dams.includes).every((t) => t.kindLabel == 'Dam'), isTrue);
    expect(places.where(PlaceFilter.towns.includes).every((t) => t.kindLabel == null), isTrue);
  });
}
