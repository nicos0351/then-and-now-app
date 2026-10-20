import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// The story and pronunciation of a renamed town's name, from the
/// bundled `assets/name_stories.json` (matched to towns by their stable
/// key). Read-only reference content - never stored in the database, so
/// updating the asset in an app release updates it for everyone.
class NameStory {
  const NameStory({
    required this.key,
    required this.name,
    this.say,
    this.sounds = const [],
    this.meaning,
    this.formerNameOrigin,
    this.sources = const [],
  });

  final String key;

  /// The town name this story was written for. If a user later renames
  /// the town in-app, the story no longer applies and isn't shown.
  final String name;

  /// Pronunciation respelling, stressed syllable in CAPITALS, clicks
  /// written as their letter followed by a dot (e.g. "gq·eh-BEH-rha").
  /// Null for names English speakers already know how to say.
  final String? say;

  /// Codes for the sounds worth explaining (see `sound_guide.dart`).
  final List<String> sounds;

  /// What the current name means / honours. Only set where a source was
  /// found.
  final String? meaning;

  /// Where the old (previous) name came from.
  final String? formerNameOrigin;

  /// Where [meaning] and [formerNameOrigin] were checked.
  final List<String> sources;

  bool get hasStory => meaning != null || formerNameOrigin != null;

  factory NameStory.fromJson(Map<String, dynamic> json) {
    return NameStory(
      key: json['key'] as String,
      name: json['name'] as String,
      say: json['say'] as String?,
      sounds: (json['sounds'] as List<dynamic>? ?? const []).cast<String>(),
      meaning: json['meaning'] as String?,
      formerNameOrigin: json['formerNameOrigin'] as String?,
      sources: (json['sources'] as List<dynamic>? ?? const []).cast<String>(),
    );
  }

  /// All stories, keyed by town key.
  static Future<Map<String, NameStory>> loadAll() async {
    final raw = await rootBundle.loadString('assets/name_stories.json');
    final list = (json.decode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
    return {for (final e in list) e['key'] as String: NameStory.fromJson(e)};
  }
}
