import 'dart:async';

import '../../../core/database/app_database.dart';
import '../../../core/models/game.dart';

abstract interface class GameRepository {
  Future<List<Game>> getGames(GameListType listType);
  Future<Game?> getGame(String id);
  Future<Game> saveGame(GameDraft draft, {String? id});
  Future<void> deleteGame(String id);
  Future<void> deleteGames(List<String> ids);
  Future<void> moveToLibrary(String id);
  Future<void> moveToWishlist(String id);
  Future<void> persistPositions(GameListType listType, List<Game> games);
  Future<int> get pendingOperationCount;
  Future<String?> readPreference(String key);
  Future<void> writePreference(String key, String value);
}

class DriftGameRepository implements GameRepository {
  const DriftGameRepository(
    this._database, {
    Future<void> Function()? onMutation,
  }) : _onMutation = onMutation;

  final AppDatabase _database;
  final Future<void> Function()? _onMutation;

  void _notifyMutation() {
    final sync = _onMutation?.call();
    if (sync != null) unawaited(sync.catchError((Object _) {}));
  }

  @override
  Future<List<Game>> getGames(GameListType listType) =>
      _database.getGames(listType);

  @override
  Future<Game?> getGame(String id) => _database.getGame(id);

  @override
  Future<Game> saveGame(GameDraft draft, {String? id}) async {
    final game = await _database.saveGame(draft, id: id);
    _notifyMutation();
    return game;
  }

  @override
  Future<void> deleteGame(String id) => _database.deleteGame(id);

  @override
  Future<void> deleteGames(List<String> ids) async {
    await _database.deleteGames(ids);
    if (ids.isNotEmpty) _notifyMutation();
  }

  @override
  Future<void> moveToLibrary(String id) async {
    await _database.moveToLibrary(id);
    _notifyMutation();
  }

  @override
  Future<void> moveToWishlist(String id) async {
    await _database.moveToWishlist(id);
    _notifyMutation();
  }

  @override
  Future<void> persistPositions(GameListType listType, List<Game> games) async {
    await _database.persistPositions(listType, games);
    _notifyMutation();
  }

  @override
  Future<int> get pendingOperationCount => _database.pendingOperationCount;

  @override
  Future<String?> readPreference(String key) => _database.readPreference(key);

  @override
  Future<void> writePreference(String key, String value) async {
    await _database.writePreference(key, value);
    _notifyMutation();
  }
}
