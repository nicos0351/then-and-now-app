import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sa_town_names/models/town.dart';

void main() {
  final towns = (json.decode(File('assets/towns.json').readAsStringSync()) as List)
      .map((e) => Town.fromJson(e as Map<String, dynamic>))
      .toList();

  Town named(String name) => towns.singleWhere((t) => t.currentName == name);

  test('every bundled town has a unique, stable key', () {
    final keys = towns.map((t) => t.sourceKey).toList();
    expect(keys.every((k) => k != null && k.startsWith('asset:')), isTrue);
    expect(keys.toSet().length, keys.length);
  });

  test('a renamed town flips between its two names', () {
    final t = named('Polokwane');
    expect(t.displayName(false), 'Polokwane');
    expect(t.displayName(true), 'Pietersburg');
    expect(t.tappedName(false), 'Pietersburg');
  });

  test('a reverted rename shows its real previous name', () {
    final t = named('Louis Trichardt');
    expect(t.displayName(true), 'Louis Trichardt');
    expect(t.tappedName(false), isNull);
    expect(t.reverted, isTrue);
  });

  test('no renamed town also appears as a separate marker under its old name', () {
    for (final t in towns.where((t) => t.hasDifferentOldName)) {
      final clash = towns.where((o) =>
          !identical(o, t) &&
          o.province == t.province &&
          o.currentName.toLowerCase() == t.oldName.toLowerCase() &&
          (o.latitude - t.latitude).abs() < 0.05 &&
          (o.longitude - t.longitude).abs() < 0.05);
      expect(clash, isEmpty, reason: '${t.oldName} -> ${t.currentName}');
    }
  });

  test('only user-added towns count as deletable', () {
    expect(named('Polokwane').isUserAdded, isFalse);
    const added = Town(
      sourceKey: 'user:1',
      currentName: 'X',
      oldName: 'X',
      province: 'Gauteng',
      latitude: -26,
      longitude: 28,
    );
    expect(added.isUserAdded, isTrue);
  });
}
