import 'package:flutter_test/flutter_test.dart';
import 'package:my_game_list/core/models/game.dart';
import 'package:my_game_list/core/models/game_sort.dart';

Game _game(
  String id,
  String name, {
  double? rating,
  int? minutes,
  int position = 0,
}) {
  final now = DateTime.utc(2025);
  return Game(
    id: id,
    name: name,
    platformId: 'pc',
    listType: GameListType.library,
    rating: rating,
    playtimeMinutes: minutes,
    manualPosition: position,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('sortGames', () {
    test('sorts notes ascending, alphabetizes ties and keeps nulls last', () {
      final result = sortGames([
        _game('no-rating', 'A', rating: null),
        _game('b', 'Beta', rating: 8),
        _game('low', 'Low', rating: 2),
        _game('a', 'Alpha', rating: 8),
      ], GameSortMode.ratingAscending);

      expect(result.map((game) => game.id), ['low', 'a', 'b', 'no-rating']);
    });

    test('sorts notes descending while null values still come last', () {
      final result = sortGames([
        _game('null', 'A', rating: null),
        _game('low', 'Low', rating: 2),
        _game('high', 'High', rating: 9),
      ], GameSortMode.ratingDescending);

      expect(result.map((game) => game.id), ['high', 'low', 'null']);
    });

    test('uses name direction and stable ids only for duplicate names', () {
      final games = [
        _game('z', 'Same'),
        _game('b', 'Beta'),
        _game('a', 'Same'),
      ];
      expect(
        sortGames(games, GameSortMode.nameAscending).map((game) => game.id),
        ['b', 'a', 'z'],
      );
      expect(
        sortGames(games, GameSortMode.nameDescending).map((game) => game.id),
        ['a', 'z', 'b'],
      );
    });

    test('sorts playtime in either direction with missing values last', () {
      final games = [
        _game('null', 'Missing', minutes: null),
        _game('long', 'Long', minutes: 120),
        _game('short', 'Short', minutes: 45),
      ];
      expect(
        sortGames(games, GameSortMode.playtimeAscending).map((game) => game.id),
        ['short', 'long', 'null'],
      );
      expect(
        sortGames(
          games,
          GameSortMode.playtimeDescending,
        ).map((game) => game.id),
        ['long', 'short', 'null'],
      );
    });

    test(
      'uses persisted custom tie order only within that criterion group',
      () {
        final games = [
          _game('c', 'Charlie', rating: 8),
          _game('a', 'Alpha', rating: 8),
          _game('b', 'Beta', rating: 8),
          _game('low', 'Low', rating: 4),
        ];
        final result = sortGames(
          games,
          GameSortMode.ratingDescending,
          tieOrders: const {
            'ratingDescending|rating:8.0': ['c', 'b', 'a'],
          },
        );
        expect(result.map((game) => game.id), ['c', 'b', 'a', 'low']);
      },
    );

    test(
      'keeps custom tie preferences independent by direction and criterion',
      () {
        final games = [
          _game('a', 'Alpha', rating: 8, minutes: 60),
          _game('b', 'Beta', rating: 8, minutes: 60),
        ];
        final ties = <String, List<String>>{
          'ratingAscending|rating:8.0': ['b', 'a'],
          'ratingDescending|rating:8.0': ['a', 'b'],
          'playtimeDescending|playtime:60': ['b', 'a'],
        };

        expect(
          sortGames(
            games,
            GameSortMode.ratingAscending,
            tieOrders: ties,
          ).map((game) => game.id),
          ['b', 'a'],
        );
        expect(
          sortGames(
            games,
            GameSortMode.ratingDescending,
            tieOrders: ties,
          ).map((game) => game.id),
          ['a', 'b'],
        );
        expect(
          sortGames(
            games,
            GameSortMode.playtimeDescending,
            tieOrders: ties,
          ).map((game) => game.id),
          ['b', 'a'],
        );
      },
    );

    test('uses saved manual positions', () {
      final result = sortGames([
        _game('last', 'Last', position: 2),
        _game('first', 'First', position: 0),
        _game('middle', 'Middle', position: 1),
      ], GameSortMode.manual);
      expect(result.map((game) => game.id), ['first', 'middle', 'last']);
    });
  });

  group('reorderGames', () {
    test('keeps rating sort and records a custom order inside a tie', () {
      final sorted = sortGames([
        _game('a', 'Alpha', rating: 8),
        _game('b', 'Beta', rating: 8),
        _game('c', 'Charlie', rating: 8),
      ], GameSortMode.ratingDescending);
      final result = reorderGames(
        sortedGames: sorted,
        mode: GameSortMode.ratingDescending,
        oldIndex: 0,
        newIndex: 2,
      );

      expect(result.mode, GameSortMode.ratingDescending);
      expect(result.games.map((game) => game.id), ['b', 'c', 'a']);
      expect(result.tieOrders['ratingDescending|rating:8.0'], ['b', 'c', 'a']);
    });

    test('switches to manual when a drag crosses rating groups', () {
      final sorted = sortGames([
        _game('high', 'High', rating: 9),
        _game('low', 'Low', rating: 2),
      ], GameSortMode.ratingDescending);
      final result = reorderGames(
        sortedGames: sorted,
        mode: GameSortMode.ratingDescending,
        oldIndex: 0,
        newIndex: 1,
      );

      expect(result.mode, GameSortMode.manual);
      expect(result.games.map((game) => game.id), ['low', 'high']);
    });

    test('switches to manual when an alphabetical drag changes sequence', () {
      final sorted = sortGames([
        _game('a', 'Alpha'),
        _game('b', 'Beta'),
      ], GameSortMode.nameAscending);
      final result = reorderGames(
        sortedGames: sorted,
        mode: GameSortMode.nameAscending,
        oldIndex: 0,
        newIndex: 1,
      );

      expect(result.mode, GameSortMode.manual);
      expect(result.games.map((game) => game.id), ['b', 'a']);
    });

    test('keeps manual mode when an item is moved', () {
      final result = reorderGames(
        sortedGames: [
          _game('a', 'Alpha', position: 0),
          _game('b', 'Beta', position: 1),
        ],
        mode: GameSortMode.manual,
        oldIndex: 0,
        newIndex: 1,
      );
      expect(result.mode, GameSortMode.manual);
      expect(result.games.map((game) => game.id), ['b', 'a']);
    });
  });
}
