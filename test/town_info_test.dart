import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sa_town_names/models/name_story.dart';
import 'package:sa_town_names/models/town.dart';
import 'package:sa_town_names/utils/town_info.dart';

void main() {
  final towns = (json.decode(File('assets/towns.json').readAsStringSync()) as List)
      .map((e) => Town.fromJson(e as Map<String, dynamic>))
      .toList();
  final stories = {
    for (final s in (json.decode(File('assets/name_stories.json').readAsStringSync()) as List)
        .map((e) => NameStory.fromJson(e as Map<String, dynamic>)))
      s.key: s,
  };
  Town named(String name) => towns.singleWhere((t) => t.currentName == name);
  NameStory? storyOf(Town t) => stories[t.sourceKey];

  test('shared info follows the town sheet, line by line', () {
    final t = named('Gqeberha');
    final lines = townInfo(t, story: storyOf(t), showOldNames: false);
    final texts = lines.map((l) => l.text).toList();
    expect(texts.take(5), ['Gqeberha', 'Eastern Cape', 'Previous name', 'Port Elizabeth', 'Renamed in 2021']);
    expect(texts, contains('Say it'));
    expect(texts, contains('About the name Gqeberha'));
    expect(texts, contains('About the name Port Elizabeth'));
    expect(lines.last.links, isNotEmpty);
  });

  test('with previous names showing, the headline is the previous name', () {
    final t = named('Polokwane');
    final texts = townInfo(t, showOldNames: true).map((l) => l.text).toList();
    expect(texts.take(4), ['Pietersburg', 'Limpopo', 'Current name', 'Polokwane']);
  });

  test('a reverted rename shares "Same as today" and its notes', () {
    final t = named('Louis Trichardt');
    final texts = townInfo(t, showOldNames: false).map((l) => l.text).toList();
    expect(texts, containsAllInOrder(['Previous name', 'Same as today', 'Reverted to this name in 2014', t.notes]));
  });

  test('the message has the same info as plain text, with full source links', () {
    final t = named('Gqeberha');
    final story = storyOf(t)!;
    final text = townInfoText(townInfo(t, story: story, showOldNames: false));
    expect(text, startsWith('Gqeberha\nEastern Cape\n\nPrevious name: Port Elizabeth\nRenamed in 2021\n'));
    expect(text, contains('Say it: ${story.say}'));
    expect(text, contains('About the name Gqeberha: ${story.meaning}'));
    for (final url in story.sources) {
      expect(text, contains(url));
    }
    expect(text, contains('Shared from Then & Now: SA Town Names'));
  });
}
