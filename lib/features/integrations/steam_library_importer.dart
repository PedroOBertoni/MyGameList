import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/utils/steam_cover_art.dart';
import 'integration_contracts.dart';

class SteamLibraryImporter implements PlatformLibraryImporter {
  SteamLibraryImporter({http.Client? client, String? apiKey})
    : _client = client ?? http.Client(),
      _apiKey = apiKey ?? _defaultApiKey;

  static const _defaultApiKey = String.fromEnvironment('STEAM_API_KEY');
  static const _timeout = Duration(seconds: 20);
  static final _steamIdPattern = RegExp(r'^\d{17}$');
  static final _vanityPattern = RegExp(r'^[A-Za-z0-9_-]{2,64}$');

  final http.Client _client;
  final String _apiKey;

  @override
  Future<List<CatalogGame>> previewSteamLibrary(String accountId) async {
    _requireApiKey();
    final steamId = await _resolveSteamId(accountId);
    await _requirePublicProfile(steamId);

    final payload = await _getJson(
      Uri.https('api.steampowered.com', '/IPlayerService/GetOwnedGames/v1/', {
        'key': _apiKey,
        'steamid': steamId,
        'include_appinfo': 'true',
        'include_played_free_games': 'true',
        'format': 'json',
      }),
    );
    final response = _object(payload['response']);
    final rows = response?['games'];
    if (rows is! List) return const [];

    return rows
        .whereType<Map>()
        .map(_catalogGameFromRow)
        .whereType<CatalogGame>()
        .toList(growable: false);
  }

  @override
  Future<List<CatalogGame>> previewEpicLibrary(String accountId) =>
      Future<List<CatalogGame>>.error(
        const IntegrationNotConfiguredException('Importação Epic Games'),
      );

  Future<String> _resolveSteamId(String accountId) async {
    final input = accountId.trim();
    if (input.isEmpty) {
      throw const SteamLibraryImportException(
        'Informe o link do perfil público ou o SteamID64.',
      );
    }

    if (_steamIdPattern.hasMatch(input)) return input;

    var profileUrl = input;
    if (!profileUrl.contains('://') &&
        profileUrl.toLowerCase().contains('steamcommunity.com/')) {
      profileUrl = 'https://$profileUrl';
    }
    final uri = Uri.tryParse(profileUrl);
    if (uri != null && uri.host.toLowerCase().endsWith('steamcommunity.com')) {
      final segments = uri.pathSegments;
      if (segments.length >= 2 && segments.first == 'profiles') {
        final steamId = segments[1];
        if (_steamIdPattern.hasMatch(steamId)) return steamId;
      }
      if (segments.length >= 2 && segments.first == 'id') {
        return _resolveVanityUrl(segments[1]);
      }
      throw const SteamLibraryImportException(
        'O link deve apontar para um perfil Steam /id/ ou /profiles/.',
      );
    }

    if (_vanityPattern.hasMatch(input)) return _resolveVanityUrl(input);
    throw const SteamLibraryImportException(
      'Use um link de perfil Steam, um nome personalizado ou um SteamID64 válido.',
    );
  }

  Future<String> _resolveVanityUrl(String vanityUrl) async {
    final payload = await _getJson(
      Uri.https('api.steampowered.com', '/ISteamUser/ResolveVanityURL/v1/', {
        'key': _apiKey,
        'vanityurl': vanityUrl,
        'format': 'json',
      }),
    );
    final response = _object(payload['response']);
    final steamId = response?['steamid']?.toString();
    if (response?['success'] == 1 &&
        steamId != null &&
        _steamIdPattern.hasMatch(steamId)) {
      return steamId;
    }
    throw const SteamLibraryImportException(
      'Não foi possível encontrar esse perfil personalizado da Steam.',
    );
  }

  Future<void> _requirePublicProfile(String steamId) async {
    final payload = await _getJson(
      Uri.https('api.steampowered.com', '/ISteamUser/GetPlayerSummaries/v2/', {
        'key': _apiKey,
        'steamids': steamId,
        'format': 'json',
      }),
    );
    final response = _object(payload['response']);
    final players = response?['players'];
    final player = players is List && players.isNotEmpty
        ? _object(players.first)
        : null;
    if (player == null) {
      throw const SteamLibraryImportException(
        'A Steam não encontrou esse perfil. Confira o link ou SteamID64.',
      );
    }

    if (player['communityvisibilitystate'] != 3) {
      throw const SteamLibraryImportException(
        'Deixe o perfil Steam público para poder vinculá-lo ao MyGameList.',
      );
    }
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    try {
      final response = await _client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(_timeout);
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const SteamLibraryImportException(
          'A Steam recusou a consulta. Confira a chave da API e a privacidade do perfil.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw SteamLibraryImportException(
          'A Steam respondeu com erro HTTP ${response.statusCode}. Tente novamente mais tarde.',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      throw const SteamLibraryImportException(
        'A Steam retornou dados em um formato inesperado.',
      );
    } on TimeoutException {
      throw const SteamLibraryImportException(
        'A consulta à Steam demorou demais. Verifique sua conexão e tente novamente.',
      );
    } on http.ClientException {
      throw const SteamLibraryImportException(
        'Não foi possível conectar à Steam. Verifique sua conexão e tente novamente.',
      );
    } on FormatException {
      throw const SteamLibraryImportException(
        'A Steam retornou dados inválidos. Tente novamente mais tarde.',
      );
    }
  }

  CatalogGame? _catalogGameFromRow(Map row) {
    final data = row.map((key, value) => MapEntry(key.toString(), value));
    final appId = data['appid']?.toString();
    final name = data['name']?.toString().trim();
    if (appId == null || appId.isEmpty || name == null || name.isEmpty) {
      return null;
    }

    final playtime = _playtimeMinutes(data['playtime_forever']);
    return CatalogGame(
      externalId: appId,
      sourceGameId: appId,
      name: name,
      coverUrl: steamLibraryCoverUrl(appId),
      playtimeMinutes: playtime,
      platformNames: const ['PC'],
    );
  }

  int? _playtimeMinutes(Object? value) {
    final parsed = switch (value) {
      final num number when number.isFinite => number,
      final String string => num.tryParse(string.trim()),
      _ => null,
    };
    if (parsed == null || !parsed.isFinite || parsed < 0) return null;

    // Steam's playtime_forever is already measured in minutes.
    return parsed.toInt();
  }

  Map<String, dynamic>? _object(Object? value) => value is Map
      ? value.map((key, value) => MapEntry(key.toString(), value))
      : null;

  void _requireApiKey() {
    if (_apiKey.trim().isEmpty || _apiKey == 'INSERIR_CHAVE_AQUI') {
      throw const IntegrationNotConfiguredException(
        'Chave Steam ausente. Configure STEAM_API_KEY em config/rawg.local.json e reinicie o app.',
      );
    }
  }

  void close() => _client.close();
}

class SteamLibraryImportException implements Exception {
  const SteamLibraryImportException(this.message);

  final String message;

  @override
  String toString() => message;
}
