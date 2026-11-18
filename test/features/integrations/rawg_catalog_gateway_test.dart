import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_game_list/features/integrations/integration_contracts.dart';
import 'package:my_game_list/features/integrations/rawg_catalog_gateway.dart';

void main() {
  test(
    'maps real RAWG game results and paginates without using its rating',
    () async {
      var requestCount = 0;
      final client = MockClient((request) async {
        requestCount++;
        expect(request.url.host, 'api.rawg.io');
        expect(request.url.path, '/api/games');
        expect(request.url.queryParameters['key'], 'local-test-key');
        expect(request.url.queryParameters['page_size'], '20');
        return http.Response(
          jsonEncode({
            'count': 21,
            'next': 'https://api.rawg.io/api/games?page=2',
            'results': [
              {
                'id': 123,
                'slug': 'elden-ring',
                'name': 'Elden Ring',
                'background_image': 'https://media.rawg.io/elden-ring.jpg',
                'released': '2022-02-25',
                'rating': 4.5,
                'platforms': [
                  {
                    'platform': {'id': 4, 'name': 'PC'},
                  },
                  {
                    'platform': {'id': 187, 'name': 'PlayStation 5'},
                  },
                ],
                'genres': [
                  {'name': 'Action'},
                  {'name': 'RPG'},
                ],
              },
            ],
          }),
          200,
        );
      });
      final gateway = RawgCatalogGateway(
        client: client,
        apiKey: 'local-test-key',
      );
      addTearDown(gateway.close);

      final page = await gateway.search('  elden   ring  ');
      final cached = await gateway.search('elden ring');

      expect(requestCount, 1);
      expect(page.hasMore, isTrue);
      expect(page.games, hasLength(1));
      expect(page.games.single.externalId, '123');
      expect(page.games.single.name, 'Elden Ring');
      expect(page.games.single.coverUrl, contains('elden-ring.jpg'));
      expect(page.games.single.platformNames, ['PC', 'PlayStation 5']);
      expect(page.games.single.genres, ['Action', 'RPG']);
      expect(page.games.single.releaseDate, DateTime(2022, 2, 25));
      expect(page.games.single.rawgUrl, 'https://rawg.io/games/elden-ring');
      expect(cached.games.single.name, 'Elden Ring');
    },
  );

  test('loads full RAWG description for the selected result', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/games/123');
      return http.Response(
        jsonEncode({
          'id': 123,
          'slug': 'elden-ring',
          'name': 'Elden Ring',
          'description':
              '<p>An <strong>open world</strong> RPG &amp; adventure.</p>',
          'released': '2022-02-25',
          'background_image': 'https://media.rawg.io/elden-ring.jpg',
          'platforms': [
            {
              'platform': {'id': 4, 'name': 'PC'},
            },
          ],
          'genres': [
            {'name': 'RPG'},
          ],
        }),
        200,
      );
    });
    final gateway = RawgCatalogGateway(
      client: client,
      apiKey: 'local-test-key',
    );
    addTearDown(gateway.close);
    const initial = CatalogGame(externalId: '123', name: 'Elden Ring');

    final details = await gateway.getDetails(initial);

    expect(details.description, 'An open world RPG & adventure.');
    expect(details.platformNames, ['PC']);
    expect(details.genres, ['RPG']);
    expect(details.sourceGameId, 'elden-ring');
  });

  test('reports an unconfigured key and an exhausted API limit', () async {
    final missingKey = RawgCatalogGateway(apiKey: '');
    addTearDown(missingKey.close);
    await expectLater(
      missingKey.search('Elden Ring'),
      throwsA(isA<IntegrationNotConfiguredException>()),
    );

    final limited = RawgCatalogGateway(
      apiKey: 'local-test-key',
      client: MockClient((_) async => http.Response('rate limit', 429)),
    );
    addTearDown(limited.close);
    await expectLater(
      limited.search('Elden Ring'),
      throwsA(isA<CatalogSearchException>()),
    );
  });
}
