import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_game_list/core/models/game.dart';
import 'package:my_game_list/core/providers/app_providers.dart';
import 'package:my_game_list/core/theme/app_theme.dart';
import 'package:my_game_list/features/library/game_list_screen.dart';

void main() {
  testWidgets('wishlist redesign fits a narrow phone screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    final now = DateTime.utc(2025);
    final game = Game(
      id: 'wish-1',
      name: 'A long game name to exercise the wishlist card layout',
      platformId: 'playstation_5',
      listType: GameListType.wishlist,
      rating: 9.5,
      playtimeMinutes: 1250,
      wishlistStatus: WishlistStatus.owned,
      createdAt: now,
      updatedAt: now,
    );
    final overrides = [
      gamesProvider.overrideWith((ref, listType) async => [game]),
      listPreferencesProvider.overrideWith(
        (ref, listType) async =>
            const ListPreferences(sortMode: GameSortMode.manual, tieOrders: {}),
      ),
      pendingOperationCountProvider.overrideWith((ref) async => 0),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const GameListScreen(listType: GameListType.wishlist),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Buscar jogo...'), findsOneWidget);
    expect(find.text(game.name), findsOneWidget);
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('Já tenho'), findsNothing);
    expect(find.text('Total'), findsNothing);
    expect(find.text('9.5'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.longPress(
      find.byTooltip('Toque para adicionar; segure para ordenar desejos'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ordem manual'), findsOneWidget);
    expect(find.text('Nome: A–Z'), findsOneWidget);
    expect(find.text('Nome: Z–A'), findsOneWidget);
    expect(find.text('Horas: maior primeiro'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('library fits a narrow phone screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    final now = DateTime.utc(2025);
    final games = [
      Game(
        id: 'g1',
        name: 'A long game name to exercise the library card layout',
        platformId: 'playstation_5',
        listType: GameListType.library,
        rating: 9.5,
        playtimeMinutes: 1250,
        status: GameStatus.completed,
        createdAt: now,
        updatedAt: now,
      ),
      Game(
        id: 'g2',
        name: 'Second game',
        platformId: 'nintendo_switch_2',
        listType: GameListType.library,
        status: GameStatus.playing,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    final overrides = [
      gamesProvider.overrideWith((ref, listType) async => games),
      listPreferencesProvider.overrideWith(
        (ref, listType) async =>
            const ListPreferences(sortMode: GameSortMode.manual, tieOrders: {}),
      ),
      pendingOperationCountProvider.overrideWith((ref) async => 0),
    ];

    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            theme: theme,
            home: const GameListScreen(listType: GameListType.library),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (theme.brightness == Brightness.dark) {
        await tester.tap(find.byTooltip('Filtros da biblioteca'));
        await tester.pumpAndSettle();
        expect(find.text('Ordenação e filtros'), findsOneWidget);
        expect(find.text('Ordenar por'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    }
  });
}
