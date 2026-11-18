import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../models/game.dart';
import '../theme/theme_controller.dart';
import '../../features/integrations/integration_contracts.dart';
import '../../features/integrations/rawg_catalog_gateway.dart';
import '../../features/games/data/game_repository.dart';

final databaseProvider = FutureProvider<AppDatabase>((ref) async {
  final database = AppDatabase();
  ref.onDispose(() => database.close());
  return database;
});

final gameRepositoryProvider = FutureProvider<GameRepository>((ref) async {
  final database = await ref.watch(databaseProvider.future);
  return DriftGameRepository(database);
});

final gamesProvider = FutureProvider.family<List<Game>, GameListType>(
  (ref, listType) async =>
      (await ref.watch(gameRepositoryProvider.future)).getGames(listType),
);

final gameProvider = FutureProvider.family<Game?, String>(
  (ref, id) async =>
      (await ref.watch(gameRepositoryProvider.future)).getGame(id),
);

final pendingOperationCountProvider = FutureProvider<int>(
  (ref) async =>
      (await ref.watch(gameRepositoryProvider.future)).pendingOperationCount,
);

class ListPreferences {
  const ListPreferences({required this.sortMode, required this.tieOrders});

  final GameSortMode sortMode;
  final Map<String, List<String>> tieOrders;
}

final listPreferencesProvider =
    FutureProvider.family<ListPreferences, GameListType>((ref, listType) async {
      final repository = await ref.watch(gameRepositoryProvider.future);
      final modeValue = await repository.readPreference(
        '${listType.name}.sort',
      );
      final tieValue = await repository.readPreference('${listType.name}.ties');
      final mode = GameSortMode.values.where((item) => item.name == modeValue);
      final Map<String, List<String>> ties = {};
      if (tieValue != null) {
        try {
          final decoded = jsonDecode(tieValue) as Map<String, dynamic>;
          for (final entry in decoded.entries) {
            ties[entry.key] = (entry.value as List<dynamic>).cast<String>();
          }
        } on FormatException {
          // A malformed preference should fall back to deterministic sorting.
        } on TypeError {
          // A malformed preference should fall back to deterministic sorting.
        }
      }
      return ListPreferences(
        sortMode: mode.isEmpty ? GameSortMode.manual : mode.first,
        tieOrders: ties,
      );
    });

final themeControllerProvider = Provider<ThemeController>((ref) {
  final controller = ThemeController();
  ref.onDispose(controller.dispose);
  return controller;
});

final catalogGatewayProvider = Provider<GameCatalogGateway>((ref) {
  final gateway = RawgCatalogGateway();
  ref.onDispose(gateway.close);
  return gateway;
});

final authGatewayProvider = Provider<AuthGateway>(
  (ref) => const UnconfiguredAuthGateway(),
);

final platformLibraryImporterProvider = Provider<PlatformLibraryImporter>(
  (ref) => const UnconfiguredPlatformLibraryImporter(),
);

final syncBackendProvider = Provider<SyncBackend>(
  (ref) => const UnconfiguredSyncBackend(),
);
