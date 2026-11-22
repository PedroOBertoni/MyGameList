import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_game_list/core/models/game.dart';
import 'package:my_game_list/features/library/game_list_screen.dart';

void main() {
  Game wishlistGame({String name = 'Example Wish'}) => Game(
    id: 'wish-game',
    name: name,
    platformId: 'pc',
    listType: GameListType.wishlist,
    rating: 9.8,
    playtimeMinutes: 120,
    wishlistStatus: WishlistStatus.owned,
    createdAt: DateTime.utc(2025),
    updatedAt: DateTime.utc(2025),
  );

  Future<void> showCard(
    WidgetTester tester,
    Game game, {
    int position = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              WishlistGameCard(
                game: game,
                position: position,
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
    await tester.pumpAndSettle();
  }

  testWidgets('wishlist card only shows rank, game details and drag handle', (
    tester,
  ) async {
    await showCard(tester, wishlistGame());

    expect(find.text('#1'), findsOneWidget);
    expect(find.text('Example Wish'), findsOneWidget);
    expect(find.text('9.8'), findsNothing);
    expect(find.text('2.0 h'), findsNothing);
    expect(find.text('Já tenho'), findsNothing);
    expect(find.byIcon(Icons.drag_indicator_rounded), findsOneWidget);
  });

  testWidgets('wishlist rank stays prefixed past position five', (
    tester,
  ) async {
    await showCard(
      tester,
      wishlistGame(name: 'A very long game title'),
      position: 7,
    );

    expect(find.text('#7'), findsOneWidget);
    expect(find.text('Iniciado'), findsNothing);
  });

  testWidgets('wishlist card fits a narrow phone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await showCard(tester, wishlistGame(name: 'A very long game title'));

    expect(tester.takeException(), isNull);
  });
}
