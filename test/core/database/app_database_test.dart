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
    rating: 8.5,
    playtimeMinutes: 135,
    status: listType == GameListType.library ? GameStatus.playing : null,
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
    await database.moveToLibrary(game.id, GameStatus.playing);
    final moved = await database.getGame(game.id);

    expect(moved?.listType, GameListType.library);
    expect(moved?.status, GameStatus.playing);
    expect(moved?.rating, 8.5);
    expect(moved?.playtimeMinutes, 135);
    expect(await database.getGames(GameListType.wishlist), isEmpty);
  });

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
