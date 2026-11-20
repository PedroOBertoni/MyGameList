import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_game_list/core/models/game.dart';
import 'package:my_game_list/features/library/game_list_screen.dart';

void main() {
  testWidgets('game card shows its platform, status and optional rating', (
    tester,
  ) async {
    final now = DateTime.utc(2025);
    final game = Game(
      id: 'game-1',
      name: 'A Short Hike',
      platformId: 'nintendo_switch',
      listType: GameListType.library,
      rating: 9.5,
      playtimeMinutes: 90,
      status: GameStatus.completed,
      createdAt: now,
      updatedAt: now,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              GameCard(
                game: game,
                position: 1,
                index: 0,
                draggable: false,
                selected: false,
                selectionMode: false,
                onEdit: () {},
                onOpen: () {},
                onLongPress: () {},
                onDelete: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('A Short Hike'), findsOneWidget);
    expect(find.text('Nintendo Switch'), findsOneWidget);
    expect(find.text('Concluído'), findsOneWidget);
    expect(find.text('9.5'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    expect(find.text('1.5h'), findsOneWidget);
  });
}
