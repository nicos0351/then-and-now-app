import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/town.dart';
import 'town_asset_loader.dart';

/// Wraps a local SQLite database (via sqflite) holding the nationwide
/// town dataset (current name, and previous name where one
/// is documented). The DB lives entirely on-device - after the first
/// seed, no network or asset reads are needed to browse the map.
///
/// Two kinds of rows exist side by side:
///  - rows seeded from `assets/towns.json` (the bundled dataset)
///  - rows a user has added or edited in-app (a new town, or a newly
///    recorded rename for a town that was renamed after this app shipped)
///
/// Every row has a stable `source_key`. Bundled towns carry theirs in
/// the `key` field of `assets/towns.json`, so it stays the same even when
/// a town's name or coordinates are corrected in a later release. That
/// lets [reseedIfNeeded] apply data fixes to existing installs:
///  - bundled rows the user hasn't touched are updated in place (or
///    inserted if new, or removed if dropped from the asset, e.g. a
///    merged duplicate)
///  - rows the user has edited (`is_user_edited = 1`) and towns the user
///    added (`user:` keys) are never changed or removed.
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const _dbName = 'sa_town_names.db';
  static const _dbVersion = 3;
  static const table = 'towns';

  // Bump this whenever assets/towns.json changes so existing installs
  // re-sync with it on next launch. Rows the user has edited or added
  // are never touched by a re-sync. It shares one number sequence with
  // the `dataVersion` of the live data file (see RemoteDataService):
  // before a release, set it to at least the latest published version.
  //  2: original ~1,000-town GeoNames dataset
  //  3: stable keys, duplicate rename markers merged, missing renames
  //     added, Louis Trichardt corrected
  //  4: renamed airports, dams and a mountain pass added (`kind`)
  //  5: clearer wording in three town notes
  //  6: eight more renamed towns, years set to the official gazette dates,
  //     Bela-Bela spelling, full Louis Trichardt story
  //  7: all of South Africa's airports, dams and mountain passes
  //     (OpenStreetMap), 11 more renames among them
  static const int seedVersion = 7;

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await _createSchema(db);
        await _seedFromAsset(db);
        await _setStoredSeedVersion(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // v1 -> v2: add source_key / is_user_edited, then backfill a
          // deterministic source_key onto every pre-existing row so the
          // asset-merge logic below can tell "already have this" apart
          // from "new town added since the last seed".
          await db.execute('ALTER TABLE $table ADD COLUMN source_key TEXT');
          await db.execute('ALTER TABLE $table ADD COLUMN is_user_edited INTEGER NOT NULL DEFAULT 0');
          final rows = await db.query(table);
          final batch = db.batch();
          for (final row in rows) {
            batch.update(
              table,
              {
                'source_key': _sourceKeyFor(
                  row['current_name'] as String,
                  row['latitude'] as double,
                  row['longitude'] as double,
                ),
              },
              where: 'id = ?',
              whereArgs: [row['id']],
            );
          }
          await batch.commit(noResult: true);
          await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_towns_source_key ON $table(source_key)');
        }
        if (oldVersion < 3) {
          // v2 -> v3: airports, dams and passes join the towns. Existing
          // rows are all towns, which the column default covers.
          await db.execute("ALTER TABLE $table ADD COLUMN kind TEXT NOT NULL DEFAULT 'town'");
        }
      },
    );
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE $table (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source_key TEXT UNIQUE,
        current_name TEXT NOT NULL,
        kind TEXT NOT NULL DEFAULT 'town',
        old_name TEXT NOT NULL,
        province TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        renamed_year INTEGER,
        has_known_rename INTEGER NOT NULL DEFAULT 0,
        reverted INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        population INTEGER NOT NULL DEFAULT 0,
        is_user_edited INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE meta (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }

  /// Deterministic key for a bundled-asset row. The `key` values in
  /// towns.json were generated with this same formula from each town's
  /// original name and coordinates, so they match what older installs
  /// already stored; this is only used as a fallback for asset rows that
  /// don't carry a `key` (and by the v1 -> v2 migration).
  String _sourceKeyFor(String name, double lat, double lon) {
    final n = name.toLowerCase().trim();
    return 'asset:$n:${lat.toStringAsFixed(3)}:${lon.toStringAsFixed(3)}';
  }

  Future<void> _seedFromAsset(DatabaseExecutor db) async {
    await _syncTowns(db, await TownAssetLoader.loadAll());
  }

  /// Brings the bundled-dataset rows in line with [towns] (from the
  /// bundled `assets/towns.json`, or a downloaded update): inserts new
  /// towns, updates untouched ones in place (keeping their row ids), and
  /// deletes untouched rows whose key is no longer in the data. Anything
  /// the user edited or added is left exactly as is.
  Future<void> _syncTowns(DatabaseExecutor db, List<Town> towns) async {
    final userEditedKeys = (await db.query(
      table,
      columns: ['source_key'],
      where: 'is_user_edited = 1 AND source_key IS NOT NULL',
    ))
        .map((r) => r['source_key'] as String)
        .toSet();

    final assetKeys = <String>{};
    final batch = db.batch();
    for (final town in towns) {
      final key = town.sourceKey ?? _sourceKeyFor(town.currentName, town.latitude, town.longitude);
      assetKeys.add(key);
      if (userEditedKeys.contains(key)) continue;

      final map = town.toMap()..remove('id');
      map['source_key'] = key;
      map['is_user_edited'] = 0;
      // Insert if missing; otherwise update in place so the row id (and
      // anything keyed on it) stays stable.
      batch.insert(table, map, conflictAlgorithm: ConflictAlgorithm.ignore);
      batch.update(table, map, where: 'source_key = ? AND is_user_edited = 0', whereArgs: [key]);
    }

    final staleRows = await db.query(
      table,
      columns: ['source_key'],
      where: "source_key LIKE 'asset:%' AND is_user_edited = 0",
    );
    for (final row in staleRows) {
      final key = row['source_key'] as String;
      if (!assetKeys.contains(key)) {
        batch.delete(table, where: 'source_key = ? AND is_user_edited = 0', whereArgs: [key]);
      }
    }
    await batch.commit(noResult: true);
  }

  Future<void> _setStoredSeedVersion(DatabaseExecutor db, [int version = seedVersion]) async {
    await db.insert(
      'meta',
      {'key': 'seed_version', 'value': '$version'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// The version of the town data on this phone: the bundled
  /// [seedVersion], or a higher `dataVersion` downloaded since. Bundled
  /// and downloaded data share one version sequence, so an app update
  /// never replaces newer downloaded data with older bundled data.
  Future<int> dataVersion() async {
    final db = await database;
    final rows = await db.query('meta', where: 'key = ?', whereArgs: ['seed_version']);
    return rows.isEmpty ? 0 : int.tryParse(rows.first['value'] as String? ?? '0') ?? 0;
  }

  /// Applies downloaded town data (already validated by
  /// RemoteDataService) and records its version - in one transaction, so
  /// a failure leaves the previous data untouched.
  Future<void> applyTownData(List<Town> towns, int version) async {
    final db = await database;
    await db.transaction((txn) async {
      await _syncTowns(txn, towns);
      await _setStoredSeedVersion(txn, version);
    });
  }

  /// Re-syncs with the bundled asset when [seedVersion] has gone up since
  /// the last sync. Safe to call every launch - user edits/additions are
  /// always preserved (see [_seedFromAsset]).
  Future<void> reseedIfNeeded() async {
    final db = await database;
    final storedVersion = await dataVersion();
    if (storedVersion < seedVersion) {
      await db.transaction((txn) async {
        await _seedFromAsset(txn);
        await _setStoredSeedVersion(txn);
      });
    }
  }

  Future<List<Town>> getAllTowns() async {
    final db = await database;
    final rows = await db.query(table, orderBy: 'current_name ASC');
    return rows.map(Town.fromMap).toList();
  }

  /// Saves an edit to an *existing* town: its current name and province,
  /// and its previous name. Used both to fill in a missing
  /// old name and to record a brand-new rename (the town's previous
  /// current name becomes [oldName], and [currentName] is the new one).
  Future<Town> updateTown({
    required int id,
    required String currentName,
    required String oldName,
    required String province,
    int? renamedYear,
    bool reverted = false,
    String? notes,
  }) async {
    final db = await database;
    await db.update(
      table,
      {
        'current_name': currentName,
        'old_name': oldName,
        'province': province,
        'has_known_rename': 1,
        'renamed_year': renamedYear,
        'reverted': reverted ? 1 : 0,
        'notes': notes,
        'is_user_edited': 1,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    final rows = await db.query(table, where: 'id = ?', whereArgs: [id]);
    return Town.fromMap(rows.first);
  }

  /// Clears a previously-recorded rename on a town, reverting it to
  /// "no rename on record" (e.g. to undo a mistaken entry). The old name
  /// is reset to the current one so it no longer matches in search.
  Future<Town> clearTownRename(int id) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE $table SET old_name = current_name, has_known_rename = 0, renamed_year = NULL, '
      'reverted = 0, notes = NULL, is_user_edited = 1 WHERE id = ?',
      [id],
    );
    final rows = await db.query(table, where: 'id = ?', whereArgs: [id]);
    return Town.fromMap(rows.first);
  }

  /// Adds a brand-new town that isn't in the bundled dataset at all
  /// (e.g. a very recently renamed or newly-established town).
  Future<Town> addUserTown(Town town) async {
    final db = await database;
    final map = town.toMap()..remove('id');
    map['source_key'] = 'user:${DateTime.now().microsecondsSinceEpoch}';
    map['is_user_edited'] = 1;
    final id = await db.insert(table, map);
    final rows = await db.query(table, where: 'id = ?', whereArgs: [id]);
    return Town.fromMap(rows.first);
  }

  /// Removes a user-added town. Bundled towns can't be deleted (they'd
  /// only come back on the next re-sync); the `user:` guard enforces that
  /// even if a caller gets it wrong. Returns true if a row was removed.
  Future<bool> deleteUserTown(int id) async {
    final db = await database;
    final count = await db.delete(table, where: "id = ? AND source_key LIKE 'user:%'", whereArgs: [id]);
    return count > 0;
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _db = null;
  }
}
