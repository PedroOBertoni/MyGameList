import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_game_list/features/integrations/steam_library_importer.dart';

void main() {
  test(
    'maps playtime_forever as minutes and preserves unknown values',
    () async {
      final client = MockClient((request) async {
        if (request.url.path == '/ISteamUser/GetPlayerSummaries/v2/') {
          return http.Response(
            jsonEncode({
              'response': {
                'players': [
                  {'communityvisibilitystate': 3},
                ],
              },
            }),
            200,
          );
        }
        if (request.url.path == '/IPlayerService/GetOwnedGames/v1/') {
          return http.Response(
            jsonEncode({
              'response': {
                'games': [
                  {'appid': 10, 'name': 'Zero', 'playtime_forever': 0},
                  {'appid': 11, 'name': 'One', 'playtime_forever': 1},
                  {'appid': 12, 'name': 'Thirty', 'playtime_forever': 30},
                  {'appid': 13, 'name': 'One Twenty', 'playtime_forever': 120},
                  {'appid': 14, 'name': 'Null', 'playtime_forever': null},
                  {'appid': 15, 'name': 'Unavailable'},
                ],
              },
            }),
            200,
          );
        }
        fail('Unexpected Steam request: ${request.url}');
      });
      final importer = SteamLibraryImporter(client: client, apiKey: 'test-key');
      addTearDown(importer.close);

      final games = await importer.previewSteamLibrary('76561198000000000');
      final playtimeById = {
        for (final game in games) game.externalId: game.playtimeMinutes,
      };

      expect(playtimeById, {
        '10': 0,
        '11': 1,
        '12': 30,
        '13': 120,
        '14': null,
        '15': null,
      });
    },
  );
}
