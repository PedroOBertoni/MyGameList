import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_game_list/core/database/app_database.dart';
import 'package:my_game_list/core/models/game.dart';

class _VersionOneDatabase extends AppDatabase {
  _VersionOneDatabase(super.executor);

  @override
  int get schemaVersion => 1;

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
    },
  );
}

void main() {
  test(
    'upgrades version one wishlist rows without losing stored data',
    () async {
      final temporaryDirectory = await Directory.systemTemp.createTemp(
        'my-game-list-migration-',
      );
      addTearDown(() => temporaryDirectory.delete(recursive: true));
      final file = File(
        '${temporaryDirectory.path}${Platform.pathSeparator}legacy.sqlite',
      );

      final legacy = _VersionOneDatabase(NativeDatabase(file));
      await legacy.customStatement(
        '''
        INSERT INTO games (
          id, name, platform_id, rating, playtime_minutes, start_date,
          completion_date, status, list_type, manual_position, created_at,
          updated_at, local_sync_status
        ) VALUES (?, ?, ?, ?, ?, ?, ?, NULL, 'wishlist', 4, ?, ?, 'synced')
      ''',
        [
          'legacy-wishlist-game',
          'Legacy wishlist game',
          'pc',
          8.7,
          300,
          '2024-01-02T00:00:00.000Z',
          '2024-01-08T00:00:00.000Z',
          '2024-01-01T00:00:00.000Z',
          '2024-01-09T00:00:00.000Z',
        ],
      );
      await legacy.close();

      final upgraded = AppDatabase(NativeDatabase(file));
      final game = await upgraded.getGame('legacy-wishlist-game');
      expect(game?.listType, GameListType.wishlist);
      expect(game?.wishlistStatus, WishlistStatus.wantToBuy);
      expect(game?.status, isNull);
      expect(game?.rating, 8.7);
      expect(game?.playtimeMinutes, 300);
      expect(game?.startDate, DateTime.utc(2024, 1, 2));
      expect(game?.completionDate, DateTime.utc(2024, 1, 8));
      expect(game?.manualPosition, 4);

      await upgraded.moveToLibrary(game!.id);
      final moved = await upgraded.getGame(game.id);
      expect(moved?.listType, GameListType.library);
      expect(moved?.status, GameStatus.notStarted);
      expect(moved?.wishlistStatus, WishlistStatus.wantToBuy);
      await upgraded.close();
    },
  );
}
