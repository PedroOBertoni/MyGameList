import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/game.dart';

/// Drift owns the SQLite connection, transactions and migration lifecycle.
/// The schema is written in SQL here to keep this first version codegen-free.
class AppDatabase extends GeneratedDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'my_game_list'));

  AppDatabase.named({required String name, QueryExecutor? executor})
    : super(executor ?? driftDatabase(name: name));

  static const _uuid = Uuid();
  static const _createGamesTable = '''
    CREATE TABLE games (
      id TEXT PRIMARY KEY NOT NULL,
      external_game_id TEXT,
      source TEXT NOT NULL DEFAULT 'manual',
      source_game_id TEXT,
      name TEXT NOT NULL,
      cover_url TEXT,
      platform_id TEXT NOT NULL,
      rating REAL CHECK (rating IS NULL OR (rating >= 0 AND rating <= 10)),
      playtime_minutes INTEGER CHECK (playtime_minutes IS NULL OR playtime_minutes >= 0),
      start_date TEXT,
      completion_date TEXT,
      status TEXT CHECK (status IS NULL OR status IN ('notStarted', 'playing', 'completed', 'dropped')),
      wishlist_status TEXT CHECK (wishlist_status IS NULL OR wishlist_status IN ('want_to_buy', 'owned', 'started')),
      list_type TEXT NOT NULL CHECK (list_type IN ('library', 'wishlist')),
      manual_position INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      deleted_at TEXT,
      local_sync_status TEXT NOT NULL DEFAULT 'pending',
      remote_version INTEGER
    )
  ''';

  @override
  int get schemaVersion => 3;

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  @override
  Iterable<DatabaseSchemaEntity> get allSchemaEntities => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      await customStatement(_createGamesTable);
      await customStatement(
        'CREATE INDEX idx_games_list ON games(list_type, deleted_at, manual_position)',
      );
      await customStatement('''
            CREATE TABLE sync_operations (
              operation_id TEXT PRIMARY KEY NOT NULL,
              entity_id TEXT NOT NULL UNIQUE,
              operation_type TEXT NOT NULL,
              payload TEXT NOT NULL,
              created_at TEXT NOT NULL,
              attempt_count INTEGER NOT NULL DEFAULT 0,
              last_error TEXT,
              sync_status TEXT NOT NULL DEFAULT 'pending'
            )
          ''');
      await customStatement('''
            CREATE TABLE app_preferences (
              preference_key TEXT PRIMARY KEY NOT NULL,
              preference_value TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.database.customStatement('''
          ALTER TABLE games ADD COLUMN wishlist_status TEXT
            CHECK (wishlist_status IS NULL OR wishlist_status IN ('want_to_buy', 'owned', 'started'))
        ''');
        await m.database.customStatement('''
          UPDATE games
          SET wishlist_status = CASE status
                WHEN 'playing' THEN 'started'
                WHEN 'completed' THEN 'owned'
                WHEN 'dropped' THEN 'owned'
                ELSE 'want_to_buy'
              END,
              status = NULL
          WHERE list_type = 'wishlist'
        ''');
      }
      if (from < 3) {
        await m.database.customStatement('DROP INDEX IF EXISTS idx_games_list');
        await m.database.customStatement(
          'ALTER TABLE games RENAME TO games_before_status_v3',
        );
        await m.database.customStatement(_createGamesTable);
        await m.database.customStatement('''
          INSERT INTO games (
            id, external_game_id, source, source_game_id, name, cover_url,
            platform_id, rating, playtime_minutes, start_date, completion_date,
            status, wishlist_status, list_type, manual_position, created_at,
            updated_at, deleted_at, local_sync_status, remote_version
          )
          SELECT
            id, external_game_id, source, source_game_id, name, cover_url,
            platform_id, rating, playtime_minutes, start_date, completion_date,
            status, wishlist_status, list_type, manual_position, created_at,
            updated_at, deleted_at, local_sync_status, remote_version
          FROM games_before_status_v3
        ''');
        await m.database.customStatement('DROP TABLE games_before_status_v3');
        await m.database.customStatement(
          'CREATE INDEX idx_games_list ON games(list_type, deleted_at, manual_position)',
        );
      }
    },
  );

  Future<List<Game>> getGames(GameListType listType) async {
    final rows = await customSelect(
      'SELECT * FROM games WHERE list_type = ? AND deleted_at IS NULL',
      variables: [Variable.withString(listType.name)],
    ).get();
    return rows.map((row) => Game.fromRow(row.data)).toList();
  }

  Future<Game?> getGame(String id) async {
    final rows = await customSelect(
      'SELECT * FROM games WHERE id = ? AND deleted_at IS NULL LIMIT 1',
      variables: [Variable.withString(id)],
    ).get();
    return rows.isEmpty ? null : Game.fromRow(rows.first.data);
  }

  Future<Game> saveGame(
    GameDraft draft, {
    String? id,
    bool preserveLegacyWishlistData = false,
  }) async {
    if (draft.listType == GameListType.wishlist && draft.status != null) {
      throw ArgumentError.value(
        draft.status,
        'status',
        'O status da Biblioteca não pode ser usado na Lista de desejos.',
      );
    }
    final now = DateTime.now().toUtc();
    final existing = id == null ? null : await getGame(id);
    final gameId = id ?? _uuid.v4();
    var position = existing?.manualPosition;

    await transaction(() async {
      if (existing == null || existing.listType != draft.listType) {
        final rows = await customSelect(
          '''SELECT COALESCE(MAX(manual_position), -1) + 1 AS next_position
             FROM games WHERE list_type = ? AND deleted_at IS NULL''',
          variables: [Variable.withString(draft.listType.name)],
        ).get();
        position = rows.first.data['next_position']! as int;
      }
      final createdAt = existing?.createdAt ?? now;
      final isWishlist = draft.listType == GameListType.wishlist;
      final startDate = isWishlist
          ? existing?.startDate ??
                (preserveLegacyWishlistData ? draft.startDate : null)
          : draft.startDate;
      final completionDate = isWishlist
          ? existing?.completionDate ??
                (preserveLegacyWishlistData ? draft.completionDate : null)
          : draft.completionDate;
      final start = startDate?.toUtc().toIso8601String();
      final completion = completionDate?.toUtc().toIso8601String();
      await customStatement(
        '''
        INSERT INTO games (
          id, external_game_id, source, source_game_id, name, cover_url,
          platform_id, rating, playtime_minutes, start_date, completion_date,
          status, wishlist_status, list_type, manual_position, created_at, updated_at, deleted_at,
          local_sync_status, remote_version
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, 'pending', ?)
        ON CONFLICT(id) DO UPDATE SET
          external_game_id = excluded.external_game_id,
          source = excluded.source,
          source_game_id = excluded.source_game_id,
          name = excluded.name,
          cover_url = excluded.cover_url,
          platform_id = excluded.platform_id,
          rating = excluded.rating,
          playtime_minutes = excluded.playtime_minutes,
          start_date = excluded.start_date,
          completion_date = excluded.completion_date,
          status = excluded.status,
          wishlist_status = excluded.wishlist_status,
          list_type = excluded.list_type,
          manual_position = excluded.manual_position,
          updated_at = excluded.updated_at,
          deleted_at = NULL,
          local_sync_status = 'pending'
      ''',
        [
          gameId,
          draft.externalGameId,
          draft.source.name,
          draft.sourceGameId,
          draft.name.trim(),
          _emptyToNull(draft.coverUrl),
          draft.platformId,
          draft.listType == GameListType.wishlist
              ? existing?.rating ??
                    (preserveLegacyWishlistData ? draft.rating : null)
              : draft.rating,
          isWishlist
              ? existing?.playtimeMinutes ??
                    (preserveLegacyWishlistData ? draft.playtimeMinutes : null)
              : draft.playtimeMinutes,
          start,
          completion,
          draft.listType == GameListType.wishlist ? null : draft.status?.name,
          isWishlist
              ? existing?.wishlistStatus?.storageValue ??
                    (preserveLegacyWishlistData
                        ? draft.wishlistStatus?.storageValue
                        : null)
              : draft.wishlistStatus?.storageValue,
          draft.listType.name,
          position,
          createdAt.toIso8601String(),
          now.toIso8601String(),
          existing?.remoteVersion,
        ],
      );
      final saved = await getGame(gameId);
      await _queueGame(saved!, type: 'upsert');
    });
    return (await getGame(gameId))!;
  }

  Future<void> deleteGame(String id) => deleteGames([id]);

  Future<void> deleteGames(List<String> ids) async {
    final uniqueIds = ids.toSet();
    if (uniqueIds.isEmpty) return;

    final now = DateTime.now().toUtc();
    await transaction(() async {
      for (final id in uniqueIds) {
        final existingRows = await customSelect(
          'SELECT * FROM games WHERE id = ? AND deleted_at IS NULL',
          variables: [Variable.withString(id)],
        ).get();
        if (existingRows.isEmpty) continue;

        await customStatement(
          '''
          UPDATE games SET deleted_at = ?, updated_at = ?, local_sync_status = 'pending'
          WHERE id = ? AND deleted_at IS NULL
        ''',
          [now.toIso8601String(), now.toIso8601String(), id],
        );
        final deletedRows = await customSelect(
          'SELECT * FROM games WHERE id = ?',
          variables: [Variable.withString(id)],
        ).get();
        if (deletedRows.isNotEmpty) {
          await _queueGame(
            Game.fromRow(deletedRows.first.data),
            type: 'delete',
          );
        }
      }
    });
  }

  Future<void> moveToLibrary(String id) async {
    final now = DateTime.now().toUtc();
    await transaction(() async {
      final rows = await customSelect(
        'SELECT * FROM games WHERE id = ? AND deleted_at IS NULL',
        variables: [Variable.withString(id)],
      ).get();
      if (rows.isEmpty) return;
      final game = Game.fromRow(rows.first.data);
      if (game.listType == GameListType.library) return;
      final next = await customSelect(
        '''SELECT COALESCE(MAX(manual_position), -1) + 1 AS next_position
           FROM games WHERE list_type = 'library' AND deleted_at IS NULL''',
      ).get();
      await customStatement(
        '''
        UPDATE games SET list_type = 'library', status = ?, manual_position = ?,
          updated_at = ?, local_sync_status = 'pending' WHERE id = ?
      ''',
        [
          GameStatus.notStarted.name,
          next.first.data['next_position'],
          now.toIso8601String(),
          id,
        ],
      );
      await _queueGame((await getGame(id))!, type: 'upsert');
    });
  }

  Future<void> moveToWishlist(String id) async {
    final now = DateTime.now().toUtc();
    await transaction(() async {
      final rows = await customSelect(
        'SELECT * FROM games WHERE id = ? AND deleted_at IS NULL',
        variables: [Variable.withString(id)],
      ).get();
      if (rows.isEmpty) return;
      final game = Game.fromRow(rows.first.data);
      if (game.listType == GameListType.wishlist) return;
      final next = await customSelect(
        '''SELECT COALESCE(MAX(manual_position), -1) + 1 AS next_position
           FROM games WHERE list_type = 'wishlist' AND deleted_at IS NULL''',
      ).get();
      await customStatement(
        '''
        UPDATE games SET list_type = 'wishlist', status = NULL,
          manual_position = ?, updated_at = ?,
          local_sync_status = 'pending' WHERE id = ?
      ''',
        [next.first.data['next_position'], now.toIso8601String(), id],
      );
      await _queueGame((await getGame(id))!, type: 'upsert');
    });
  }

  Future<void> persistPositions(
    GameListType listType,
    List<Game> orderedGames,
  ) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await transaction(() async {
      for (var index = 0; index < orderedGames.length; index++) {
        final game = orderedGames[index];
        await customStatement(
          '''
          UPDATE games SET manual_position = ?, updated_at = ?, local_sync_status = 'pending'
          WHERE id = ? AND list_type = ? AND deleted_at IS NULL
        ''',
          [index, now, game.id, listType.name],
        );
        final rows = await customSelect(
          'SELECT * FROM games WHERE id = ?',
          variables: [Variable.withString(game.id)],
        ).get();
        if (rows.isNotEmpty) {
          await _queueGame(Game.fromRow(rows.first.data), type: 'upsert');
        }
      }
    });
  }

  Future<void> _queueGame(Game game, {required String type}) async {
    await _queueOperation(game.id, type, jsonEncode(game.toJson()));
  }

  Future<void> _queueOperation(
    String entityId,
    String type,
    String payload,
  ) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await customStatement(
      '''
      INSERT INTO sync_operations (
        operation_id, entity_id, operation_type, payload, created_at,
        attempt_count, last_error, sync_status
      ) VALUES (?, ?, ?, ?, ?, 0, NULL, 'pending')
      ON CONFLICT(entity_id) DO UPDATE SET
        operation_type = excluded.operation_type,
        payload = excluded.payload,
        created_at = excluded.created_at,
        last_error = NULL,
        sync_status = 'pending'
    ''',
      [_uuid.v4(), entityId, type, payload, now],
    );
  }

  Future<int> get pendingOperationCount async {
    final rows = await customSelect(
      "SELECT COUNT(*) AS count FROM sync_operations WHERE sync_status != 'synced'",
    ).get();
    return rows.first.data['count']! as int;
  }

  Future<List<Map<String, Object?>>> getPendingOperations() async {
    final rows = await customSelect(
      "SELECT * FROM sync_operations WHERE sync_status != 'synced' ORDER BY created_at ASC",
    ).get();
    return rows.map((row) => row.data).toList();
  }

  Future<String?> readPreference(String key) async {
    final rows = await customSelect(
      'SELECT preference_value FROM app_preferences WHERE preference_key = ?',
      variables: [Variable.withString(key)],
    ).get();
    return rows.isEmpty ? null : rows.first.data['preference_value']! as String;
  }

  Future<void> writePreference(String key, String value) async {
    final updatedAt = DateTime.now().toUtc().toIso8601String();
    await transaction(() async {
      await _writePreferenceLocally(key, value, updatedAt);
      await _queueOperation(
        'preference:$key',
        'preference',
        jsonEncode({'key': key, 'value': value, 'updatedAt': updatedAt}),
      );
    });
  }

  Future<List<Map<String, Object?>>> getAllPreferences() async {
    final rows = await customSelect('SELECT * FROM app_preferences').get();
    return rows.map((row) => row.data).toList();
  }

  Future<void> applyRemotePreference({
    required String key,
    required String value,
    required String updatedAt,
  }) async {
    final entityId = 'preference:$key';
    final pendingRows = await customSelect(
      "SELECT 1 FROM sync_operations WHERE entity_id = ? AND sync_status != 'synced' LIMIT 1",
      variables: [Variable.withString(entityId)],
    ).get();
    if (pendingRows.isNotEmpty) return;

    final localRows = await customSelect(
      'SELECT updated_at FROM app_preferences WHERE preference_key = ? LIMIT 1',
      variables: [Variable.withString(key)],
    ).get();
    if (localRows.isNotEmpty) {
      final localUpdatedAt = DateTime.tryParse(
        localRows.first.data['updated_at']! as String,
      );
      final remoteUpdatedAt = DateTime.tryParse(updatedAt);
      if (localUpdatedAt != null &&
          remoteUpdatedAt != null &&
          !remoteUpdatedAt.isAfter(localUpdatedAt)) {
        return;
      }
    }
    await _writePreferenceLocally(key, value, updatedAt);
  }

  Future<void> _writePreferenceLocally(
    String key,
    String value,
    String updatedAt,
  ) => customStatement(
    '''
      INSERT INTO app_preferences(preference_key, preference_value, updated_at)
      VALUES (?, ?, ?)
      ON CONFLICT(preference_key) DO UPDATE SET
        preference_value = excluded.preference_value, updated_at = excluded.updated_at
    ''',
    [key, value, updatedAt],
  );

  Future<void> markSyncOperationSynced({
    required String operationId,
    required String entityId,
  }) async {
    await transaction(() async {
      final rows = await customSelect(
        'SELECT operation_type FROM sync_operations WHERE entity_id = ? AND operation_id = ? LIMIT 1',
        variables: [
          Variable.withString(entityId),
          Variable.withString(operationId),
        ],
      ).get();
      if (rows.isEmpty) return;

      final operationType = rows.first.data['operation_type']! as String;
      await customStatement(
        'DELETE FROM sync_operations WHERE entity_id = ? AND operation_id = ?',
        [entityId, operationId],
      );
      if (operationType != 'preference') {
        await customStatement(
          "UPDATE games SET local_sync_status = 'synced' WHERE id = ?",
          [entityId],
        );
      }
    });
  }

  Future<void> markSyncOperationFailed({
    required String operationId,
    required String error,
  }) => customStatement(
    '''
      UPDATE sync_operations
      SET attempt_count = attempt_count + 1, last_error = ?
      WHERE operation_id = ?
    ''',
    [error, operationId],
  );

  Future<void> applyRemoteGame(Map<String, Object?> data) async {
    final id = data['id'] as String?;
    final name = data['name'] as String?;
    final platformId = data['platformId'] as String?;
    final listType = data['listType'] as String?;
    final updatedAt = data['updatedAt'] as String?;
    if (id == null ||
        name == null ||
        platformId == null ||
        listType == null ||
        updatedAt == null ||
        !GameListType.values.any((value) => value.name == listType)) {
      return;
    }

    final pendingRows = await customSelect(
      "SELECT 1 FROM sync_operations WHERE entity_id = ? AND sync_status != 'synced' LIMIT 1",
      variables: [Variable.withString(id)],
    ).get();
    if (pendingRows.isNotEmpty) return;

    final localRows = await customSelect(
      'SELECT updated_at FROM games WHERE id = ? LIMIT 1',
      variables: [Variable.withString(id)],
    ).get();
    if (localRows.isNotEmpty) {
      final localUpdatedAt = DateTime.tryParse(
        localRows.first.data['updated_at']! as String,
      );
      final remoteUpdatedAt = DateTime.tryParse(updatedAt);
      if (localUpdatedAt != null &&
          remoteUpdatedAt != null &&
          !remoteUpdatedAt.isAfter(localUpdatedAt)) {
        return;
      }
    }

    final source = data['source'] as String? ?? GameSource.manual.name;
    final remoteStatus = data['status'] as String?;
    final isWishlist = listType == GameListType.wishlist.name;
    final status =
        isWishlist ||
            !GameStatus.values.any((value) => value.name == remoteStatus)
        ? null
        : remoteStatus;
    final wishlistStatus = data.containsKey('wishlistStatus')
        ? wishlistStatusFromStorage(data['wishlistStatus'])
        : isWishlist
        ? switch (remoteStatus) {
            'playing' => WishlistStatus.started,
            'completed' || 'dropped' => WishlistStatus.owned,
            _ => WishlistStatus.wantToBuy,
          }
        : null;
    final createdAt = data['createdAt'] as String? ?? updatedAt;
    final remoteVersion = data['remoteVersion'] as int? ?? 1;
    final deletedAt = data['deletedAt'] as String?;
    await customStatement(
      '''
      INSERT INTO games (
        id, external_game_id, source, source_game_id, name, cover_url,
        platform_id, rating, playtime_minutes, start_date, completion_date,
        status, wishlist_status, list_type, manual_position, created_at, updated_at, deleted_at,
        local_sync_status, remote_version
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'synced', ?)
      ON CONFLICT(id) DO UPDATE SET
        external_game_id = excluded.external_game_id,
        source = excluded.source,
        source_game_id = excluded.source_game_id,
        name = excluded.name,
        cover_url = excluded.cover_url,
        platform_id = excluded.platform_id,
        rating = excluded.rating,
        playtime_minutes = excluded.playtime_minutes,
        start_date = excluded.start_date,
        completion_date = excluded.completion_date,
        status = excluded.status,
        wishlist_status = excluded.wishlist_status,
        list_type = excluded.list_type,
        manual_position = excluded.manual_position,
        created_at = excluded.created_at,
        updated_at = excluded.updated_at,
        deleted_at = excluded.deleted_at,
        local_sync_status = 'synced',
        remote_version = excluded.remote_version
      ''',
      [
        id,
        data['externalGameId'],
        source,
        data['sourceGameId'],
        name,
        data['coverUrl'],
        platformId,
        (data['rating'] as num?)?.toDouble(),
        (data['playtimeMinutes'] as num?)?.toInt(),
        data['startDate'],
        data['completionDate'],
        status,
        wishlistStatus?.storageValue,
        listType,
        (data['manualPosition'] as num?)?.toInt() ?? 0,
        createdAt,
        updatedAt,
        deletedAt,
        remoteVersion,
      ],
    );
  }

  Future<int> importGuestDataOnce(AppDatabase guestDatabase) async {
    const migrationKey = 'internal.guest_data_imported_v1';
    if (await guestDatabase.readPreference(migrationKey) == 'true') return 0;

    var importedGames = 0;
    for (final listType in GameListType.values) {
      final games = await guestDatabase.getGames(listType);
      for (final game in games) {
        final existingRows = await customSelect(
          'SELECT id FROM games WHERE id = ? LIMIT 1',
          variables: [Variable.withString(game.id)],
        ).get();
        if (existingRows.isNotEmpty) continue;
        await saveGame(
          GameDraft(
            name: game.name,
            platformId: game.platformId,
            listType: game.listType,
            source: game.source,
            externalGameId: game.externalGameId,
            sourceGameId: game.sourceGameId,
            coverUrl: game.coverUrl,
            rating: game.rating,
            playtimeMinutes: game.playtimeMinutes,
            startDate: game.startDate,
            completionDate: game.completionDate,
            status: game.status,
            wishlistStatus: game.wishlistStatus,
          ),
          id: game.id,
          preserveLegacyWishlistData: true,
        );
        importedGames++;
      }
    }

    for (final preference in await guestDatabase.getAllPreferences()) {
      final key = preference['preference_key']! as String;
      if (key.startsWith('internal.')) continue;
      if (await readPreference(key) == null) {
        await writePreference(key, preference['preference_value']! as String);
      }
    }

    await guestDatabase._writePreferenceLocally(
      migrationKey,
      'true',
      DateTime.now().toUtc().toIso8601String(),
    );
    return importedGames;
  }

  static String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
