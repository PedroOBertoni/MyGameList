import '../../../core/database/app_database.dart';
import '../../../core/models/game.dart';

abstract interface class GameRepository {
  Future<List<Game>> getGames(GameListType listType);
  Future<Game?> getGame(String id);
  Future<Game> saveGame(GameDraft draft, {String? id});
  Future<void> deleteGame(String id);
  Future<void> deleteGames(List<String> ids);
  Future<void> moveToLibrary(String id, GameStatus status);
  Future<void> persistPositions(GameListType listType, List<Game> games);
  Future<int> get pendingOperationCount;
  Future<String?> readPreference(String key);
  Future<void> writePreference(String key, String value);
}

class DriftGameRepository implements GameRepository {
  const DriftGameRepository(this._database);

  final AppDatabase _database;

  @override
  Future<List<Game>> getGames(GameListType listType) =>
      _database.getGames(listType);

  @override
  Future<Game?> getGame(String id) => _database.getGame(id);

  @override
  Future<Game> saveGame(GameDraft draft, {String? id}) =>
      _database.saveGame(draft, id: id);

  @override
  Future<void> deleteGame(String id) => _database.deleteGame(id);

  @override
  Future<void> deleteGames(List<String> ids) => _database.deleteGames(ids);

  @override
  Future<void> moveToLibrary(String id, GameStatus status) =>
      _database.moveToLibrary(id, status);

  @override
  Future<void> persistPositions(GameListType listType, List<Game> games) =>
      _database.persistPositions(listType, games);

  @override
  Future<int> get pendingOperationCount => _database.pendingOperationCount;

  @override
  Future<String?> readPreference(String key) => _database.readPreference(key);

  @override
  Future<void> writePreference(String key, String value) =>
      _database.writePreference(key, value);
}
