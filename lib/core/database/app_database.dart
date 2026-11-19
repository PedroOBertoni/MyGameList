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

  static const _uuid = Uuid();

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  @override
  Iterable<DatabaseSchemaEntity> get allSchemaEntities => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) async {
      await customStatement('''
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
              status TEXT CHECK (status IS NULL OR status IN ('playing', 'completed', 'dropped')),
              list_type TEXT NOT NULL CHECK (list_type IN ('library', 'wishlist')),
              manual_position INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              deleted_at TEXT,
              local_sync_status TEXT NOT NULL DEFAULT 'pending',
              remote_version INTEGER
            )
          ''');
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

  Future<Game> saveGame(GameDraft draft, {String? id}) async {
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
      final start = draft.startDate?.toUtc().toIso8601String();
      final completion = draft.completionDate?.toUtc().toIso8601String();
      await customStatement(
        '''
        INSERT INTO games (
          id, external_game_id, source, source_game_id, name, cover_url,
          platform_id, rating, playtime_minutes, start_date, completion_date,
          status, list_type, manual_position, created_at, updated_at, deleted_at,
          local_sync_status, remote_version
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, 'pending', ?)
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
          draft.rating,
          draft.playtimeMinutes,
          start,
          completion,
          draft.listType == GameListType.wishlist ? null : draft.status?.name,
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
          await _queueGame(Game.fromRow(deletedRows.first.data), type: 'delete');
        }
      }
    });
  }

  Future<void> moveToLibrary(String id, GameStatus status) async {
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
          status.name,
          next.first.data['next_position'],
          now.toIso8601String(),
          id,
        ],
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
      [_uuid.v4(), game.id, type, jsonEncode(game.toJson()), now],
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
    await customStatement(
      '''
      INSERT INTO app_preferences(preference_key, preference_value, updated_at)
      VALUES (?, ?, ?)
      ON CONFLICT(preference_key) DO UPDATE SET
        preference_value = excluded.preference_value, updated_at = excluded.updated_at
    ''',
      [key, value, DateTime.now().toUtc().toIso8601String()],
    );
  }

  static String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
