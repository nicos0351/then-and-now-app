import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sa_town_names/models/place_facts.dart';
import 'package:sa_town_names/models/town.dart';
import 'package:sa_town_names/utils/town_info.dart';

void main() {
  final places = (json.decode(File('assets/towns.json').readAsStringSync()) as List)
      .map((e) => Town.fromJson(e as Map<String, dynamic>))
      .toList();
  final facts = PlaceFacts.parseList(json.decode(File('assets/place_facts.json').readAsStringSync()) as List);
  final byKey = {for (final t in places) t.sourceKey: t};

  test('every facts entry belongs to an airport, dam or pass', () {
    expect(facts, isNotEmpty);
    for (final f in facts.values) {
      final place = byKey[f.key];
      expect(place, isNotNull, reason: f.key);
      expect(place!.isTown, isFalse, reason: place.currentName);
      expect(f.facts, isNotEmpty, reason: place.currentName);
    }
  });

  test('every airport has its codes', () {
    for (final t in places.where((t) => t.kind == 'airport')) {
      final f = facts[t.sourceKey];
      expect(f, isNotNull, reason: t.currentName);
      expect(f!.facts.first.$1, 'Airport codes', reason: t.currentName);
    }
  });

  test('heights are in metres and believable', () {
    for (final f in facts.values) {
      for (final (label, value) in f.facts) {
        if (!label.contains('eight')) continue;
        expect(value, endsWith(' m'), reason: '${f.key}: $label');
        final metres = double.parse(value.replaceAll(RegExp(r'[^\d.]'), ''));
        expect(metres, inInclusiveRange(1, 3500), reason: '${f.key}: $label $value');
      }
    }
  });

  test('bad entries are rejected', () {
    expect(() => PlaceFacts.fromJson({'key': 'asset:x', 'facts': []}), throwsFormatException);
    expect(() => PlaceFacts.fromJson({'key': 'asset:x', 'facts': [['only a label']]}), throwsFormatException);
  });

  test('shared info ends with the facts, as the sheet shows them', () {
    final tambo = places.singleWhere((t) => t.currentName == 'O. R. Tambo International Airport');
    final text = townInfoText(townInfo(tambo, facts: facts[tambo.sourceKey], showOldNames: false));
    expect(text, contains('Facts:\nAirport codes: JNB · FAOR\n'));
    expect(text, contains('Height above sea level: 1,694 m'));
  });
}
