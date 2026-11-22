import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_game_list/core/database/app_database.dart';
import 'package:my_game_list/core/models/game.dart';

void main() {
  late AppDatabase database;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    await database.getGames(GameListType.library);
  });

  tearDown(() async => database.close());

  GameDraft draft({GameListType listType = GameListType.library}) => GameDraft(
    name: 'Example Game',
    platformId: 'pc',
    listType: listType,
    source: GameSource.manual,
    rating: listType == GameListType.library ? 8.5 : null,
    playtimeMinutes: listType == GameListType.library ? 135 : null,
    status: listType == GameListType.library ? GameStatus.playing : null,
    wishlistStatus: null,
  );

  test(
    'saves games and groups repeated edits in one pending queue row',
    () async {
      final first = await database.saveGame(draft());
      expect(first.id, isNotEmpty);
      expect(first.rating, 8.5);
      expect(first.playtimeMinutes, 135);
      expect(await database.pendingOperationCount, 1);

      final edited = await database.saveGame(
        const GameDraft(
          name: 'Renamed Game',
          platformId: 'pc',
          listType: GameListType.library,
          source: GameSource.manual,
          status: GameStatus.completed,
        ),
        id: first.id,
      );
      expect(edited.name, 'Renamed Game');
      expect(edited.rating, isNull);
      expect(edited.startDate, isNull);
      expect(await database.pendingOperationCount, 1);
      final queued = await database.getPendingOperations();
      expect(queued.single['operation_type'], 'upsert');
    },
  );

  test(
    'persists the RAWG id and slug without changing personal fields',
    () async {
      const selected = GameDraft(
        name: 'Selected from RAWG',
        platformId: 'playstation_5',
        listType: GameListType.library,
        source: GameSource.rawg,
        externalGameId: 'rawg-123',
        sourceGameId: 'selected-from-rawg',
        coverUrl: 'https://example.test/cover.webp',
        rating: 9.2,
        playtimeMinutes: 240,
        status: GameStatus.completed,
      );

      final saved = await database.saveGame(selected);
      final loaded = await database.getGame(saved.id);

      expect(loaded?.externalGameId, 'rawg-123');
      expect(loaded?.sourceGameId, 'selected-from-rawg');
      expect(loaded?.source, GameSource.rawg);
      expect(loaded?.coverUrl, selected.coverUrl);
      expect(loaded?.rating, 9.2);
      expect(loaded?.playtimeMinutes, 240);
      expect(loaded?.status, GameStatus.completed);
    },
  );

  test('soft deletes locally and keeps a pending delete operation', () async {
    final game = await database.saveGame(draft());
    await database.deleteGame(game.id);

    expect(await database.getGames(GameListType.library), isEmpty);
    expect(await database.pendingOperationCount, 1);
    expect(
      (await database.getPendingOperations()).single['operation_type'],
      'delete',
    );
  });

  test('moves a wishlist game without losing user-entered fields', () async {
    final game = await database.saveGame(
      draft(listType: GameListType.wishlist),
    );
    await database.moveToLibrary(game.id);
    final moved = await database.getGame(game.id);

    expect(moved?.listType, GameListType.library);
    expect(moved?.status, GameStatus.notStarted);
    expect(moved?.wishlistStatus, isNull);
    expect(moved?.rating, isNull);
    expect(moved?.playtimeMinutes, isNull);
    expect(await database.getGames(GameListType.wishlist), isEmpty);
  });

  test(
    'moves an evaluated game to wishlist and back without data loss',
    () async {
      final game = await database.saveGame(
        GameDraft(
          name: 'Rated game',
          platformId: 'pc',
          listType: GameListType.library,
          source: GameSource.manual,
          rating: 9.5,
          playtimeMinutes: 870,
          startDate: DateTime.utc(2024, 1, 2),
          completionDate: DateTime.utc(2024, 1, 10),
          status: GameStatus.completed,
        ),
      );

      await database.moveToWishlist(game.id);
      final wish = await database.getGame(game.id);
      expect(wish?.id, game.id);
      expect(wish?.listType, GameListType.wishlist);
      expect(wish?.status, isNull);
      expect(wish?.wishlistStatus, isNull);
      expect(wish?.rating, 9.5);
      expect(wish?.playtimeMinutes, 870);
      expect(wish?.startDate, DateTime.utc(2024, 1, 2));
      expect(wish?.completionDate, DateTime.utc(2024, 1, 10));

      final queuedPayload =
          (jsonDecode(
                (await database.getPendingOperations()).single['payload']!
                    as String,
              )
              as Map<String, dynamic>);
      expect(queuedPayload['wishlistStatus'], isNull);
      expect(queuedPayload['rating'], 9.5);

      await database.moveToLibrary(game.id);
      final returned = await database.getGame(game.id);
      expect(returned?.listType, GameListType.library);
      expect(returned?.status, GameStatus.notStarted);
      expect(returned?.wishlistStatus, isNull);
      expect(returned?.rating, 9.5);
      expect(returned?.playtimeMinutes, 870);
      expect(returned?.completionDate, DateTime.utc(2024, 1, 10));
    },
  );

  test(
    'new wishlist games do not contain library fields or a wishlist status',
    () async {
      final saved = await database.saveGame(
        GameDraft(
          name: 'Wish game',
          platformId: 'pc',
          listType: GameListType.wishlist,
          source: GameSource.manual,
          rating: 7,
          playtimeMinutes: 120,
          startDate: DateTime.utc(2024, 1, 2),
          completionDate: DateTime.utc(2024, 1, 10),
          wishlistStatus: WishlistStatus.owned,
        ),
      );

      expect(saved.rating, isNull);
      expect(saved.status, isNull);
      expect(saved.wishlistStatus, isNull);
      expect(saved.playtimeMinutes, isNull);
      expect(saved.startDate, isNull);
      expect(saved.completionDate, isNull);
      expect(saved.toJson()['wishlistStatus'], isNull);
      final payload =
          jsonDecode(
                (await database.getPendingOperations()).single['payload']!
                    as String,
              )
              as Map<String, dynamic>;
      expect(payload['rating'], isNull);
      expect(payload['status'], isNull);
      expect(payload['wishlistStatus'], isNull);
    },
  );

  test('rejects a library status on a wishlist game', () async {
    await expectLater(
      database.saveGame(
        const GameDraft(
          name: 'Wrong status',
          platformId: 'pc',
          listType: GameListType.wishlist,
          source: GameSource.manual,
          status: GameStatus.playing,
          wishlistStatus: WishlistStatus.owned,
        ),
      ),
      throwsArgumentError,
    );
  });

  test('guest import preserves a hidden legacy wishlist rating', () async {
    final previousWarningSetting =
        driftRuntimeOptions.dontWarnAboutMultipleDatabases;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    addTearDown(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases =
          previousWarningSetting;
    });
    final guestDatabase = AppDatabase(NativeDatabase.memory());
    addTearDown(guestDatabase.close);
    await guestDatabase.getGames(GameListType.wishlist);
    final legacyWish = await guestDatabase.saveGame(
      draft(listType: GameListType.wishlist),
    );
    await guestDatabase.customStatement(
      '''UPDATE games SET rating = ?, playtime_minutes = ?, start_date = ?,
         completion_date = ?, wishlist_status = ? WHERE id = ?''',
      [
        8.6,
        240,
        '2024-01-02T00:00:00.000Z',
        '2024-01-10T00:00:00.000Z',
        'owned',
        legacyWish.id,
      ],
    );

    final importedCount = await database.importGuestDataOnce(guestDatabase);
    final imported = await database.getGame(legacyWish.id);

    expect(importedCount, 1);
    expect(imported?.listType, GameListType.wishlist);
    expect(imported?.rating, 8.6);
    expect(imported?.playtimeMinutes, 240);
    expect(imported?.startDate, DateTime.utc(2024, 1, 2));
    expect(imported?.completionDate, DateTime.utc(2024, 1, 10));
    expect(imported?.wishlistStatus, WishlistStatus.owned);
  });

  test(
    'remote wishlist documents stay compatible with old and new schemas',
    () async {
      const oldRemote = <String, Object?>{
        'id': 'legacy-wish',
        'name': 'Old wishlist game',
        'platformId': 'pc',
        'listType': 'wishlist',
        'status': 'completed',
        'rating': 8.2,
        'updatedAt': '2024-01-01T00:00:00.000Z',
      };
      await database.applyRemoteGame(oldRemote);
      final migrated = await database.getGame('legacy-wish');
      expect(migrated?.status, isNull);
      expect(migrated?.wishlistStatus, WishlistStatus.owned);
      expect(migrated?.rating, 8.2);

      await database.applyRemoteGame(const {
        'id': 'new-wish',
        'name': 'New wishlist game',
        'platformId': 'pc',
        'listType': 'wishlist',
        'wishlistStatus': 'want_to_buy',
        'updatedAt': '2024-01-02T00:00:00.000Z',
      });
      expect(
        (await database.getGame('new-wish'))?.wishlistStatus,
        WishlistStatus.wantToBuy,
      );
    },
  );

  test(
    'persists manual positions and list sort preferences in SQLite',
    () async {
      final first = await database.saveGame(draft());
      final second = await database.saveGame(
        const GameDraft(
          name: 'Second Game',
          platformId: 'pc',
          listType: GameListType.library,
          source: GameSource.manual,
          status: GameStatus.playing,
        ),
      );
      await database.persistPositions(GameListType.library, [second, first]);
      await database.writePreference('library.sort', GameSortMode.manual.name);

      final games = await database.getGames(GameListType.library);
      games.sort((a, b) => a.manualPosition.compareTo(b.manualPosition));
      expect(games.map((game) => game.id), [second.id, first.id]);
      expect(await database.readPreference('library.sort'), 'manual');
    },
  );
}
