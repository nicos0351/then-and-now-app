class Town {
  final int? id;

  /// Stable identity of the row. `asset:...` for towns from the bundled
  /// `assets/towns.json` (the `key` field there), `user:...` for towns
  /// the user added in-app. Null only for a [Town] not yet saved.
  final String? sourceKey;
  final String currentName;

  /// What sort of place this is: 'town' (the default), 'airport', 'dam'
  /// or 'pass'. Only towns count for "Where am I?".
  final String kind;

  /// The previous name. Equals [currentName] when there is
  /// no rename, and also for a rename that was later reverted (e.g.
  /// Louis Trichardt, whose previous name is the same as today's).
  final String oldName;
  final String province;
  final double latitude;
  final double longitude;
  final int? renamedYear;

  /// True for towns with a documented name change (including one that
  /// was later reverted). For the rest of the country's towns, [oldName]
  /// just mirrors [currentName].
  final bool hasKnownRename;

  /// True when the rename was later reverted back to the old name
  /// (e.g. Louis Trichardt -> Makhado -> Louis Trichardt).
  final bool reverted;
  final String? notes;
  final int population;

  /// True when this row was added or edited by the user in-app, rather
  /// than coming straight from the bundled asset.
  final bool isUserEdited;

  const Town({
    this.id,
    this.sourceKey,
    required this.currentName,
    this.kind = 'town',
    required this.oldName,
    required this.province,
    required this.latitude,
    required this.longitude,
    this.renamedYear,
    this.hasKnownRename = false,
    this.reverted = false,
    this.notes,
    this.population = 0,
    this.isUserEdited = false,
  });

  /// True for towns the user created in-app (not from the bundled data).
  /// Only these can be deleted.
  bool get isUserAdded => sourceKey?.startsWith('user:') ?? false;

  bool get isTown => kind == 'town';

  /// "Airport", "Dam", "Mountain pass", or null for towns.
  String? get kindLabel => switch (kind) {
        'airport' => 'Airport',
        'dam' => 'Dam',
        'pass' => 'Mountain pass',
        _ => null,
      };

  /// True when the previous name differs from today's name, i.e. there
  /// is something to show when the map is flipped.
  bool get hasDifferentOldName =>
      hasKnownRename && oldName.trim().toLowerCase() != currentName.trim().toLowerCase();

  /// Name to show on the map depending on the active display mode.
  /// Towns with no recorded rename always show their one true name.
  String displayName(bool showOldNames) {
    if (!hasDifferentOldName) return currentName;
    return showOldNames ? oldName : currentName;
  }

  /// The name the town had in [year], for the timeline slider. A rename
  /// with no recorded year is treated as happening in [todayYear], so the
  /// old name shows until the slider reaches "Today".
  String nameInYear(int year, {required int todayYear}) {
    if (!hasDifferentOldName) return currentName;
    final changedIn = renamedYear ?? todayYear;
    return year < changedIn ? oldName : currentName;
  }

  /// Name to show when the user taps the town (the "other" name),
  /// or null when there's nothing different to reveal.
  String? tappedName(bool showOldNames) {
    if (!hasDifferentOldName) return null;
    return showOldNames ? currentName : oldName;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'source_key': sourceKey,
      'current_name': currentName,
      'kind': kind,
      'old_name': oldName,
      'province': province,
      'latitude': latitude,
      'longitude': longitude,
      'renamed_year': renamedYear,
      'has_known_rename': hasKnownRename ? 1 : 0,
      'reverted': reverted ? 1 : 0,
      'notes': notes,
      'population': population,
      'is_user_edited': isUserEdited ? 1 : 0,
    };
  }

  factory Town.fromMap(Map<String, dynamic> map) {
    return Town(
      id: map['id'] as int?,
      sourceKey: map['source_key'] as String?,
      currentName: map['current_name'] as String,
      kind: map['kind'] as String? ?? 'town',
      oldName: map['old_name'] as String,
      province: map['province'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      renamedYear: map['renamed_year'] as int?,
      hasKnownRename: (map['has_known_rename'] as int? ?? 0) == 1,
      reverted: (map['reverted'] as int? ?? 0) == 1,
      notes: map['notes'] as String?,
      population: map['population'] as int? ?? 0,
      isUserEdited: (map['is_user_edited'] as int? ?? 0) == 1,
    );
  }

  factory Town.fromJson(Map<String, dynamic> json) {
    return Town(
      sourceKey: json['key'] as String?,
      currentName: json['name'] as String,
      kind: json['kind'] as String? ?? 'town',
      oldName: json['oldName'] as String,
      province: json['province'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      renamedYear: json['renamedYear'] as int?,
      hasKnownRename: json['hasKnownRename'] as bool? ?? false,
      reverted: json['reverted'] as bool? ?? false,
      notes: json['notes'] as String?,
      population: json['population'] as int? ?? 0,
    );
  }
}
