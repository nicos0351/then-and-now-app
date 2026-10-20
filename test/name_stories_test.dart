import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sa_town_names/models/name_story.dart';
import 'package:sa_town_names/models/town.dart';
import 'package:sa_town_names/utils/sound_guide.dart';

void main() {
  final towns = (json.decode(File('assets/towns.json').readAsStringSync()) as List)
      .map((e) => Town.fromJson(e as Map<String, dynamic>))
      .toList();
  final stories = (json.decode(File('assets/name_stories.json').readAsStringSync()) as List)
      .map((e) => NameStory.fromJson(e as Map<String, dynamic>))
      .toList();
  final townsByKey = {for (final t in towns) t.sourceKey!: t};

  test('every story belongs to a town, under that town\'s name', () {
    for (final s in stories) {
      final town = townsByKey[s.key];
      expect(town, isNotNull, reason: s.key);
      expect(town!.currentName, s.name);
    }
  });

  test('every renamed town (not airport, dam or pass) has a story entry', () {
    final storyKeys = stories.map((s) => s.key).toSet();
    for (final t in towns.where((t) => t.hasDifferentOldName && t.isTown)) {
      expect(storyKeys, contains(t.sourceKey), reason: t.currentName);
    }
  });

  test('every sound code has a tip', () {
    for (final s in stories) {
      for (final code in s.sounds) {
        expect(soundTips.containsKey(code), isTrue, reason: '${s.name}: $code');
      }
    }
  });

  test('every meaning or old-name origin cites a source', () {
    for (final s in stories.where((s) => s.hasStory)) {
      expect(s.sources, isNotEmpty, reason: s.name);
    }
  });
}
