import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sa_town_names/models/town.dart';

void main() {
  final towns = (json.decode(File('assets/towns.json').readAsStringSync()) as List)
      .map((e) => Town.fromJson(e as Map<String, dynamic>))
      .toList();
  Town named(String name) => towns.singleWhere((t) => t.currentName == name);
  const today = 2026;

  test('a town shows its old name before the rename year and the new one from it', () {
    final t = named('Mbombela'); // Nelspruit, renamed 2009
    expect(t.nameInYear(1993, todayYear: today), 'Nelspruit');
    expect(t.nameInYear(2008, todayYear: today), 'Nelspruit');
    expect(t.nameInYear(2009, todayYear: today), 'Mbombela');
    expect(t.nameInYear(today, todayYear: today), 'Mbombela');
  });

  test('a rename with no recorded year changes at "Today"', () {
    final t = named('oThongathi'); // Tongaat, year not on record
    expect(t.renamedYear, isNull);
    expect(t.nameInYear(2020, todayYear: today), 'Tongaat');
    expect(t.nameInYear(today, todayYear: today), 'oThongathi');
  });

  test('towns without a different old name never change', () {
    expect(named('Louis Trichardt').nameInYear(2005, todayYear: today), 'Louis Trichardt');
    expect(named('Johannesburg').nameInYear(1993, todayYear: today), 'Johannesburg');
  });

  test('at the start every renamed town shows its old name, today none do', () {
    for (final t in towns.where((t) => t.hasDifferentOldName)) {
      expect(t.nameInYear(1993, todayYear: today), t.oldName, reason: t.currentName);
      expect(t.nameInYear(today, todayYear: today), t.currentName, reason: t.currentName);
    }
  });
}
