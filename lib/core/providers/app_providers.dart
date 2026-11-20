import 'dart:convert';
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../models/game.dart';
import '../theme/theme_controller.dart';
import '../../features/integrations/integration_contracts.dart';
import '../../features/integrations/firebase_gateways.dart';
import '../../features/integrations/rawg_catalog_gateway.dart';
import '../../features/integrations/steam_library_importer.dart';
import '../../features/games/data/game_repository.dart';

final firebaseInitializedProvider = Provider<bool>((ref) => false);

final authStateProvider = StreamProvider<User?>((ref) {
  if (!ref.watch(firebaseInitializedProvider)) return Stream.value(null);
  return FirebaseAuth.instance.authStateChanges();
});

final authStatusProvider = Provider<AsyncValue<bool>>((ref) {
  return ref.watch(authStateProvider).whenData((user) => user != null);
});

final guestDatabaseProvider = FutureProvider<AppDatabase>((ref) async {
  final database = AppDatabase();
  ref.onDispose(() => database.close());
  return database;
});

final databaseProvider = FutureProvider<AppDatabase>((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.asData?.value;
  if (user == null) return ref.watch(guestDatabaseProvider.future);

  final database = AppDatabase.named(name: 'my_game_list_user_${user.uid}');
  ref.onDispose(() => database.close());
  return database;
});

final gameRepositoryProvider = FutureProvider<GameRepository>((ref) async {
  final database = await ref.watch(databaseProvider.future);
  return DriftGameRepository(
    database,
    onMutation: () => syncCurrentAccountFromRef(ref),
  );
});

final gamesProvider = FutureProvider.family<List<Game>, GameListType>(
  (ref, listType) async =>
      (await ref.watch(gameRepositoryProvider.future)).getGames(listType),
);

final gameProvider = FutureProvider.family<Game?, String>(
  (ref, id) async =>
      (await ref.watch(gameRepositoryProvider.future)).getGame(id),
);

final pendingOperationCountProvider = FutureProvider<int>((ref) async {
  if (!ref.watch(firebaseInitializedProvider) ||
      ref.watch(authStateProvider).asData?.value == null) {
    return 0;
  }
  return (await ref.watch(gameRepositoryProvider.future)).pendingOperationCount;
});

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

final authGatewayProvider = Provider<AuthGateway>((ref) {
  if (!ref.watch(firebaseInitializedProvider)) {
    return const UnconfiguredAuthGateway();
  }
  return FirebaseAuthGateway(FirebaseAuth.instance);
});

final platformLibraryImporterProvider = Provider<PlatformLibraryImporter>((
  ref,
) {
  final importer = SteamLibraryImporter();
  ref.onDispose(importer.close);
  return importer;
});

final syncBackendProvider = Provider<SyncBackend>((ref) {
  if (!ref.watch(firebaseInitializedProvider)) {
    return const UnconfiguredSyncBackend();
  }
  final user = ref.watch(authStateProvider).asData?.value;
  final database = ref.watch(databaseProvider).asData?.value;
  if (user == null || database == null) {
    return const UnconfiguredSyncBackend();
  }
  return FirebaseSyncBackend(database: database, userId: user.uid);
});

final Map<String, Future<void>> _accountSyncFlights = {};
final Set<String> _syncRequestedAgain = {};

Future<void> syncCurrentAccountFromRef(Ref ref, {User? user}) =>
    _syncCurrentAccount(
      firebaseEnabled: ref.read(firebaseInitializedProvider),
      user: user ?? ref.read(authStateProvider).asData?.value,
      loadDatabase: () => ref.read(databaseProvider.future),
      loadGuestDatabase: () => ref.read(guestDatabaseProvider.future),
      invalidateData: () {
        ref.invalidate(gamesProvider);
        ref.invalidate(gameProvider);
        ref.invalidate(listPreferencesProvider);
        ref.invalidate(pendingOperationCountProvider);
      },
    );

Future<void> syncCurrentAccountFromWidgetRef(WidgetRef ref, {User? user}) =>
    _syncCurrentAccount(
      firebaseEnabled: ref.read(firebaseInitializedProvider),
      user: user ?? ref.read(authStateProvider).asData?.value,
      loadDatabase: () => ref.read(databaseProvider.future),
      loadGuestDatabase: () => ref.read(guestDatabaseProvider.future),
      invalidateData: () {
        ref.invalidate(gamesProvider);
        ref.invalidate(gameProvider);
        ref.invalidate(listPreferencesProvider);
        ref.invalidate(pendingOperationCountProvider);
      },
    );

Future<void> _syncCurrentAccount({
  required bool firebaseEnabled,
  required User? user,
  required Future<AppDatabase> Function() loadDatabase,
  required Future<AppDatabase> Function() loadGuestDatabase,
  required void Function() invalidateData,
}) async {
  if (!firebaseEnabled) return;
  final signedInUser = user;
  if (signedInUser == null) return;

  final existingFlight = _accountSyncFlights[signedInUser.uid];
  if (existingFlight != null) {
    _syncRequestedAgain.add(signedInUser.uid);
    return existingFlight;
  }

  final flight = _syncAccountData(
    signedInUser,
    loadDatabase: loadDatabase,
    loadGuestDatabase: loadGuestDatabase,
    invalidateData: invalidateData,
  );
  _accountSyncFlights[signedInUser.uid] = flight;
  try {
    await flight;
  } finally {
    if (identical(_accountSyncFlights[signedInUser.uid], flight)) {
      _accountSyncFlights.remove(signedInUser.uid);
    }
    if (_syncRequestedAgain.remove(signedInUser.uid)) {
      await _syncCurrentAccount(
        firebaseEnabled: firebaseEnabled,
        user: signedInUser,
        loadDatabase: loadDatabase,
        loadGuestDatabase: loadGuestDatabase,
        invalidateData: invalidateData,
      );
    }
  }
}

Future<void> _syncAccountData(
  User user, {
  required Future<AppDatabase> Function() loadDatabase,
  required Future<AppDatabase> Function() loadGuestDatabase,
  required void Function() invalidateData,
}) async {
  final database = await loadDatabase();
  final guestDatabase = await loadGuestDatabase();
  final syncBackend = FirebaseSyncBackend(database: database, userId: user.uid);

  const guestMigrationKey = 'internal.guest_data_imported_v1';
  final needsGuestMigration =
      await guestDatabase.readPreference(guestMigrationKey) != 'true';
  if (needsGuestMigration) {
    // Pull the account's existing library first so it wins over stale guest copies.
    // If Firestore is temporarily unreachable, still migrate locally and keep the
    // queued writes for the next online sync.
    try {
      await syncBackend.syncPendingChanges();
    } catch (_) {
      // The second sync below reports and retains any pending cloud failure.
    }
    await database.importGuestDataOnce(guestDatabase);
    invalidateData();
  }
  try {
    await syncBackend.syncPendingChanges();
  } finally {
    invalidateData();
  }
}
