import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_game_list/core/models/game.dart';
import 'package:my_game_list/core/providers/app_providers.dart';
import 'package:my_game_list/features/games/game_detail_screen.dart';

void main() {
  testWidgets('RAWG source appears without the duplicate attribution block', (
    tester,
  ) async {
    final now = DateTime.utc(2025);
    final game = Game(
      id: 'rawg-game',
      name: 'Example RAWG game',
      platformId: 'pc',
      listType: GameListType.library,
      source: GameSource.rawg,
      sourceGameId: 'example-rawg-game',
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [gameProvider.overrideWith((ref, id) async => game)],
        child: const MaterialApp(home: GameDetailScreen(gameId: 'rawg-game')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Origem'), findsOneWidget);
    expect(find.text('RAWG'), findsOneWidget);
    expect(find.textContaining('Dados e imagens'), findsNothing);
  });
}
