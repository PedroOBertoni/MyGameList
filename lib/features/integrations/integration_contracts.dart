enum AccountProvider { google, steam, epic }

class IntegrationNotConfiguredException implements Exception {
  const IntegrationNotConfiguredException(this.integration);

  final String integration;

  @override
  String toString() => '$integration ainda não está configurada.';
}

class CatalogGame {
  const CatalogGame({
    required this.externalId,
    required this.name,
    this.coverUrl,
    this.sourceGameId,
    this.playtimeMinutes,
    this.platformNames = const [],
    this.description,
    this.releaseDate,
    this.genres = const [],
  });

  final String externalId;
  final String name;
  final String? coverUrl;
  final String? sourceGameId;
  final int? playtimeMinutes;
  final List<String> platformNames;
  final String? description;
  final DateTime? releaseDate;
  final List<String> genres;

  String? get rawgUrl =>
      sourceGameId == null ? null : 'https://rawg.io/games/$sourceGameId';
}

class CatalogSearchPage {
  const CatalogSearchPage({required this.games, required this.hasMore});

  final List<CatalogGame> games;
  final bool hasMore;
}

abstract interface class GameCatalogGateway {
  Future<CatalogSearchPage> search(String query, {int page = 1});
  Future<CatalogGame> getDetails(CatalogGame game);
}

abstract interface class AuthGateway {
  Future<void> signInWithEmail(String email, String password);
  Future<void> createAccountWithEmail(String email, String password);
  Future<void> signInWithGoogle();
  Future<void> signInWithSteam();
  Future<void> signInWithEpic();
  Future<void> linkProvider(AccountProvider provider);
  Future<void> signOut({required bool preserveLocalData});
}

abstract interface class PlatformLibraryImporter {
  Future<List<CatalogGame>> previewSteamLibrary(String accountId);
  Future<List<CatalogGame>> previewEpicLibrary(String accountId);
}

abstract interface class SyncBackend {
  Future<void> syncPendingChanges();
}

class UnconfiguredCatalogGateway implements GameCatalogGateway {
  const UnconfiguredCatalogGateway();

  @override
  Future<CatalogSearchPage> search(String query, {int page = 1}) =>
      Future.error(const IntegrationNotConfiguredException('Pesquisa RAWG'));

  @override
  Future<CatalogGame> getDetails(CatalogGame game) =>
      Future.error(const IntegrationNotConfiguredException('Detalhes RAWG'));
}

class UnconfiguredAuthGateway implements AuthGateway {
  const UnconfiguredAuthGateway();

  @override
  Future<void> signInWithEmail(String email, String password) =>
      Future.error(const IntegrationNotConfiguredException('Firebase Auth'));

  @override
  Future<void> createAccountWithEmail(String email, String password) =>
      Future.error(const IntegrationNotConfiguredException('Firebase Auth'));

  @override
  Future<void> signInWithGoogle() =>
      Future.error(const IntegrationNotConfiguredException('Firebase Auth'));

  @override
  Future<void> signInWithSteam() =>
      Future.error(const IntegrationNotConfiguredException('Login Steam'));

  @override
  Future<void> signInWithEpic() =>
      Future.error(const IntegrationNotConfiguredException('Login Epic Games'));

  @override
  Future<void> linkProvider(AccountProvider provider) => Future.error(
    const IntegrationNotConfiguredException('Vinculação de conta'),
  );

  @override
  Future<void> signOut({required bool preserveLocalData}) =>
      Future.error(const IntegrationNotConfiguredException('Firebase Auth'));
}

class UnconfiguredPlatformLibraryImporter implements PlatformLibraryImporter {
  const UnconfiguredPlatformLibraryImporter();

  @override
  Future<List<CatalogGame>> previewSteamLibrary(String accountId) =>
      Future.error(const IntegrationNotConfiguredException('Importação Steam'));

  @override
  Future<List<CatalogGame>> previewEpicLibrary(String accountId) =>
      Future.error(
        const IntegrationNotConfiguredException('Importação Epic Games'),
      );
}

class UnconfiguredSyncBackend implements SyncBackend {
  const UnconfiguredSyncBackend();

  @override
  Future<void> syncPendingChanges() => Future.error(
    const IntegrationNotConfiguredException('Firebase/Firestore'),
  );
}
