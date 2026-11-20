import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'integration_contracts.dart';

class RawgCatalogGateway implements GameCatalogGateway {
  RawgCatalogGateway({
    http.Client? client,
    DateTime Function()? clock,
    String? apiKey,
  }) : _client = client ?? http.Client(),
       _clock = clock ?? DateTime.now,
       _apiKey = apiKey ?? _defaultApiKey;

  static const _defaultApiKey = String.fromEnvironment('RAWG_API_KEY');
  static const _cacheDuration = Duration(minutes: 10);
  static const _timeout = Duration(seconds: 12);

  final http.Client _client;
  final DateTime Function() _clock;
  final String _apiKey;
  final Map<String, _TimedValue<CatalogSearchPage>> _searchCache = {};
  final Map<String, _TimedValue<CatalogGame>> _detailsCache = {};

  @override
  Future<CatalogSearchPage> search(String query, {int page = 1}) async {
    final normalized = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length < 2) {
      return const CatalogSearchPage(games: [], hasMore: false);
    }
    if (page < 1) throw ArgumentError.value(page, 'page', 'must be positive');
    _requireApiKey();

    final cacheKey = '${normalized.toLowerCase()}|$page';
    final cached = _searchCache[cacheKey];
    if (cached != null && cached.expiresAt.isAfter(_clock())) {
      return cached.value;
    }
    _searchCache.removeWhere((_, value) => !value.expiresAt.isAfter(_clock()));

    final uri = Uri.https('api.rawg.io', '/api/games', {
      'key': _apiKey,
      'search': normalized,
      'page': '$page',
      'page_size': '20',
    });
    final response = await _get(uri);
    final payload = _decodeObject(response.body);
    final rows = payload['results'];
    if (rows is! List) {
      throw const CatalogSearchException(
        'A RAWG retornou uma resposta inválida.',
      );
    }
    final result = CatalogSearchPage(
      games: rows
          .whereType<Map>()
          .map(_gameFromSearchRow)
          .toList(growable: false),
      hasMore:
          payload['next'] is String && (payload['next'] as String).isNotEmpty,
    );
    _storeCache(_searchCache, cacheKey, result);
    return result;
  }

  @override
  Future<CatalogGame> getDetails(CatalogGame game) async {
    _requireApiKey();
    final cacheKey = game.externalId;
    final cached = _detailsCache[cacheKey];
    if (cached != null && cached.expiresAt.isAfter(_clock())) {
      return cached.value;
    }

    final uri = Uri.https('api.rawg.io', '/api/games/$cacheKey', {
      'key': _apiKey,
    });
    final response = await _get(uri);
    final payload = _decodeObject(response.body);
    final details = _gameFromDetail(payload, fallback: game);
    _storeCache(_detailsCache, cacheKey, details);
    return details;
  }

  Future<http.Response> _get(Uri uri) async {
    try {
      final response = await _client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(_timeout);
      if (response.statusCode == 429) {
        throw const CatalogSearchException(
          'O limite de consultas RAWG foi atingido. Aguarde e tente novamente.',
        );
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const CatalogSearchException(
          'A RAWG recusou a chave. Confira config/rawg.local.json e reinicie o app.',
        );
      }
      if (response.statusCode == 404) {
        throw const CatalogSearchException(
          'O jogo não foi encontrado na RAWG.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw CatalogSearchException(
          'A RAWG respondeu com erro HTTP ${response.statusCode}. Tente novamente mais tarde.',
        );
      }
      return response;
    } on TimeoutException {
      throw const CatalogSearchException(
        'A pesquisa RAWG demorou demais. Verifique a conexão e tente novamente.',
      );
    } on http.ClientException {
      throw const CatalogSearchException(
        'Sem conexão com a RAWG. O cadastro manual continua disponível.',
      );
    }
  }

  Map<String, dynamic> _decodeObject(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      throw const FormatException('O corpo não é um objeto JSON.');
    } on FormatException {
      throw const CatalogSearchException('A RAWG retornou dados inválidos.');
    }
  }

  CatalogGame _gameFromSearchRow(Map row) {
    final data = row.map((key, value) => MapEntry(key.toString(), value));
    return _gameFromMap(data);
  }

  CatalogGame _gameFromDetail(
    Map<String, dynamic> data, {
    required CatalogGame fallback,
  }) => _gameFromMap(data, fallback: fallback);

  CatalogGame _gameFromMap(Map<String, dynamic> data, {CatalogGame? fallback}) {
    final id = data['id']?.toString() ?? fallback?.externalId ?? '';
    final slug = data['slug'] as String? ?? fallback?.sourceGameId;
    final platformRows = data['platforms'];
    final genreRows = data['genres'];
    final rawDescription = data['description_raw'] as String?;
    final htmlDescription = data['description'] as String?;
    return CatalogGame(
      externalId: id,
      name: data['name'] as String? ?? fallback?.name ?? 'Jogo sem nome',
      sourceGameId: slug,
      coverUrl: data['background_image'] as String? ?? fallback?.coverUrl,
      releaseDate:
          DateTime.tryParse(data['released'] as String? ?? '') ??
          fallback?.releaseDate,
      platformNames: _namesFrom(platformRows, 'platform'),
      genres: _namesFrom(genreRows),
      description: _plainDescription(
        rawDescription ?? htmlDescription ?? fallback?.description ?? '',
      ),
    );
  }

  List<String> _namesFrom(Object? value, [String nestedKey = '']) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((row) {
          final nested = nestedKey.isEmpty ? row : row[nestedKey];
          if (nested is Map) return nested['name']?.toString() ?? '';
          return '';
        })
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
  }

  String _plainDescription(String source) => source
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  void _requireApiKey() {
    if (_apiKey.trim().isEmpty || _apiKey == 'INSERIR_CHAVE_AQUI') {
      throw const IntegrationNotConfiguredException(
        'RAWG_API_KEY não foi passada ao app. Inicie pelo perfil MyGameList (catálogos) no VS Code ou use flutter run --dart-define-from-file=config/rawg.local.json; o Flutter não carrega .env automaticamente.',
      );
    }
  }

  void _storeCache<T>(Map<String, _TimedValue<T>> cache, String key, T value) {
    cache.removeWhere((_, entry) => !entry.expiresAt.isAfter(_clock()));
    if (cache.length >= 60) cache.remove(cache.keys.first);
    cache[key] = _TimedValue(value, _clock().add(_cacheDuration));
  }

  void close() => _client.close();
}

class _TimedValue<T> {
  const _TimedValue(this.value, this.expiresAt);

  final T value;
  final DateTime expiresAt;
}

class CatalogSearchException implements Exception {
  const CatalogSearchException(this.message);

  final String message;

  @override
  String toString() => message;
}
