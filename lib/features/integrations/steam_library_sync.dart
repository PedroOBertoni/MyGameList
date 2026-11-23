import '../../core/models/game.dart';
import '../games/data/game_repository.dart';
import 'integration_contracts.dart';

class SteamLibrarySyncResult {
  const SteamLibrarySyncResult({
    required this.importedCount,
    required this.updatedCount,
    required this.duplicateCount,
  });

  final int importedCount;
  final int updatedCount;
  final int duplicateCount;
}

class SteamLibrarySync {
  const SteamLibrarySync(this._repository);

  final GameRepository _repository;

  Future<SteamLibrarySyncResult> sync(List<CatalogGame> steamGames) async {
    final existingGames = <Game>[
      ...await _repository.getGames(GameListType.library),
      ...await _repository.getGames(GameListType.wishlist),
    ];
    final existingSteamGames = <String, Game>{};
    final existingSteamIds = <String>{};
    for (final game in existingGames.where(
      (game) => game.source == GameSource.steam,
    )) {
      final id = _steamGameId(game.sourceGameId, game.externalGameId);
      if (id.isEmpty) continue;
      existingSteamIds.add(id);
      if (game.listType == GameListType.library) {
        existingSteamGames.putIfAbsent(id, () => game);
      }
    }
    final existingNames = existingGames
        .map((game) => _normalizeGameName(game.name))
        .where((name) => name.isNotEmpty)
        .toSet();

    var importedCount = 0;
    var updatedCount = 0;
    var duplicateCount = 0;
    for (final steamGame in steamGames) {
      final sourceGameId = _steamGameId(
        steamGame.sourceGameId,
        steamGame.externalId,
      );
      final existingSteamGame = existingSteamGames[sourceGameId];
      final playtimeMinutes = _validPlaytime(steamGame.playtimeMinutes);

      if (existingSteamGame != null) {
        // Unknown Steam playtime must not erase a value already saved locally.
        if (playtimeMinutes != null &&
            playtimeMinutes != existingSteamGame.playtimeMinutes) {
          await _repository.updateSteamGamePlaytime(
            existingSteamGame.id,
            playtimeMinutes,
          );
          updatedCount++;
        }
        duplicateCount++;
        continue;
      }

      if (sourceGameId.isNotEmpty && existingSteamIds.contains(sourceGameId)) {
        duplicateCount++;
        continue;
      }

      final normalizedName = _normalizeGameName(steamGame.name);
      if (normalizedName.isNotEmpty && existingNames.contains(normalizedName)) {
        duplicateCount++;
        continue;
      }

      await _repository.saveGame(
        GameDraft(
          name: steamGame.name,
          platformId: 'pc',
          listType: GameListType.library,
          source: GameSource.steam,
          externalGameId: steamGame.externalId,
          sourceGameId: sourceGameId.isEmpty ? null : sourceGameId,
          coverUrl: steamGame.coverUrl,
          playtimeMinutes: playtimeMinutes,
          status: playtimeMinutes != null && playtimeMinutes > 0
              ? GameStatus.completed
              : GameStatus.notStarted,
        ),
      );
      importedCount++;
      if (sourceGameId.isNotEmpty) existingSteamIds.add(sourceGameId);
      if (normalizedName.isNotEmpty) existingNames.add(normalizedName);
    }

    return SteamLibrarySyncResult(
      importedCount: importedCount,
      updatedCount: updatedCount,
      duplicateCount: duplicateCount,
    );
  }

  static int? _validPlaytime(int? minutes) =>
      minutes == null || minutes < 0 ? null : minutes;

  static String _steamGameId(String? sourceGameId, String? externalId) {
    final sourceId = sourceGameId?.trim();
    if (sourceId != null && sourceId.isNotEmpty) return sourceId;
    return externalId?.trim() ?? '';
  }

  static String _normalizeGameName(String value) {
    var normalized = value.trim().toLowerCase();
    const accentGroups = <String, String>{
      '\u00e1\u00e0\u00e2\u00e3\u00e4': 'a',
      '\u00e9\u00e8\u00ea\u00eb': 'e',
      '\u00ed\u00ec\u00ee\u00ef': 'i',
      '\u00f3\u00f2\u00f4\u00f5\u00f6': 'o',
      '\u00fa\u00f9\u00fb\u00fc': 'u',
      '\u00e7': 'c',
      '\u00f1': 'n',
      '\u00fd\u00ff': 'y',
    };
    for (final entry in accentGroups.entries) {
      for (final character in entry.key.split('')) {
        normalized = normalized.replaceAll(character, entry.value);
      }
    }
    return normalized.replaceAll(RegExp(r'[\s\-_\u2013\u2014:;,.!]+'), '');
  }
}
