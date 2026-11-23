import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_game_list/core/database/app_database.dart';
import 'package:my_game_list/core/models/game.dart';
import 'package:my_game_list/features/games/data/game_repository.dart';
import 'package:my_game_list/features/integrations/integration_contracts.dart';
import 'package:my_game_list/features/integrations/steam_library_sync.dart';

void main() {
  late AppDatabase database;
  late DriftGameRepository repository;
  late SteamLibrarySync steamSync;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftGameRepository(database);
    steamSync = SteamLibrarySync(repository);
    await repository.getGames(GameListType.library);
  });

  tearDown(() async => database.close());

  test(
    'assigns statuses from Steam minutes for newly imported games',
    () async {
      final result = await steamSync.sync([
        _steamGame('10', 'Zero', 0),
        _steamGame('11', 'One', 1),
        _steamGame('12', 'Thirty', 30),
        _steamGame('13', 'One Twenty', 120),
        _steamGame('14', 'Null', null),
        _steamGame('15', 'Unavailable', null),
      ]);
      final games = await repository.getGames(GameListType.library);
      final gamesBySteamId = {
        for (final game in games) game.sourceGameId!: game,
      };

      expect(result.importedCount, 6);
      expect(result.updatedCount, 0);
      expect(gamesBySteamId['10']?.playtimeMinutes, 0);
      expect(gamesBySteamId['10']?.status, GameStatus.notStarted);
      for (final id in ['11', '12', '13']) {
        expect(gamesBySteamId[id]?.status, GameStatus.completed);
      }
      expect(gamesBySteamId['11']?.playtimeMinutes, 1);
      expect(gamesBySteamId['12']?.playtimeMinutes, 30);
      expect(gamesBySteamId['13']?.playtimeMinutes, 120);
      for (final id in ['14', '15']) {
        expect(gamesBySteamId[id]?.playtimeMinutes, isNull);
        expect(gamesBySteamId[id]?.status, GameStatus.notStarted);
      }
    },
  );

  test(
    'updates existing Steam playtime without replacing personal fields',
    () async {
      final initial = await repository.saveGame(
        GameDraft(
          name: 'Meu nome personalizado',
          platformId: 'playstation_5',
          listType: GameListType.library,
          source: GameSource.steam,
          externalGameId: '42',
          sourceGameId: '42',
          coverUrl: 'https://example.test/personal-cover.webp',
          rating: 9.5,
          playtimeMinutes: 30,
          startDate: DateTime.utc(2024, 1, 2),
          completionDate: DateTime.utc(2024, 2, 3),
          status: GameStatus.dropped,
        ),
      );
      final initialPosition = initial.manualPosition;

      final firstSync = await steamSync.sync([
        _steamGame('42', 'New Steam Name', 120),
      ]);
      final saved = (await repository.getGames(GameListType.library)).single;
      final queued = (await database.getPendingOperations()).single;

      expect(firstSync.importedCount, 0);
      expect(firstSync.updatedCount, 1);
      expect(firstSync.duplicateCount, 1);
      expect(saved.id, initial.id);
      expect(saved.playtimeMinutes, 120);
      expect(saved.status, GameStatus.dropped);
      expect(saved.name, 'Meu nome personalizado');
      expect(saved.platformId, 'playstation_5');
      expect(saved.rating, 9.5);
      expect(saved.startDate, DateTime.utc(2024, 1, 2));
      expect(saved.completionDate, DateTime.utc(2024, 2, 3));
      expect(saved.coverUrl, 'https://example.test/personal-cover.webp');
      expect(saved.manualPosition, initialPosition);
      expect(queued['entity_id'], initial.id);
      expect(queued['operation_type'], 'upsert');

      final repeatedSync = await steamSync.sync([
        _steamGame('42', 'New Steam Name', 120),
        _steamGame('42', 'New Steam Name', null),
      ]);
      final gamesAfterRepeat = await repository.getGames(GameListType.library);

      expect(repeatedSync.importedCount, 0);
      expect(repeatedSync.updatedCount, 0);
      expect(gamesAfterRepeat, hasLength(1));
      expect(gamesAfterRepeat.single.playtimeMinutes, 120);
      expect(gamesAfterRepeat.single.status, GameStatus.dropped);
    },
  );

  test('does not duplicate Steam records or games matched by name', () async {
    await repository.saveGame(
      const GameDraft(
        name: 'Half-Life 2',
        platformId: 'pc',
        listType: GameListType.library,
        source: GameSource.manual,
        status: GameStatus.playing,
      ),
    );

    final result = await steamSync.sync([
      _steamGame('99', 'Half Life 2', 120),
      _steamGame('100', 'New Game', 0),
      _steamGame('100', 'New Game', 30),
    ]);
    final games = await repository.getGames(GameListType.library);

    expect(result.importedCount, 1);
    expect(result.duplicateCount, 2);
    expect(games, hasLength(2));
    expect(games.where((game) => game.sourceGameId == '100'), hasLength(1));
  });
}

CatalogGame _steamGame(String id, String name, int? playtimeMinutes) =>
    CatalogGame(
      externalId: id,
      sourceGameId: id,
      name: name,
      playtimeMinutes: playtimeMinutes,
    );
