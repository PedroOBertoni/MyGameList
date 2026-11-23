import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_game_list/core/models/game.dart';
import 'package:my_game_list/features/games/game_form_screen.dart';

void main() {
  testWidgets('selection fields keep their value and expose choices', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: GameFormScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Plataforma *'), findsOneWidget);
    expect(find.text('PC'), findsOneWidget);
    expect(find.text('Lista de destino'), findsOneWidget);
    expect(find.text('Biblioteca'), findsOneWidget);
    expect(find.text('Status da biblioteca *'), findsOneWidget);
    expect(find.text('Pendente'), findsOneWidget);

    await tester.tap(find.text('PC'));
    await tester.pumpAndSettle();
    expect(find.text('Xbox'), findsOneWidget);
    await tester.tap(find.text('Xbox'));
    await tester.pumpAndSettle();
    expect(find.text('Xbox'), findsOneWidget);
    expect(find.text('PC'), findsNothing);

    await tester.tap(find.text('Biblioteca').first);
    await tester.pumpAndSettle();
    expect(find.text('Lista de desejos'), findsOneWidget);
    await tester.tap(find.text('Lista de desejos').last);
    await tester.pumpAndSettle();
    expect(find.text('Lista de destino'), findsOneWidget);
    expect(find.text('Lista de desejos'), findsOneWidget);
    expect(find.text('Status da biblioteca *'), findsNothing);
  });

  testWidgets('manual form fits a narrow phone screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: GameFormScreen())),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('wishlist destination only asks for catalog fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: GameFormScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nota'), findsOneWidget);
    expect(find.text('Horas jogadas'), findsOneWidget);
    expect(find.text('Conclusão'), findsOneWidget);

    await tester.tap(find.text('Biblioteca').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lista de desejos').last);
    await tester.pumpAndSettle();

    expect(find.text('Status da lista de desejos *'), findsNothing);
    expect(find.text('Nota'), findsNothing);
    expect(find.textContaining('Nota'), findsNothing);
    expect(find.text('Horas jogadas'), findsNothing);
    expect(find.text('Conclusão'), findsNothing);
    expect(find.text('Status da biblioteca *'), findsNothing);
  });

  testWidgets('wishlist form has no library experience fields', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: GameFormScreen(initialListType: GameListType.wishlist),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nota'), findsNothing);
    expect(find.text('Horas jogadas'), findsNothing);
    expect(find.text('Início'), findsNothing);
    expect(find.text('Conclusão'), findsNothing);
    expect(find.text('Status da biblioteca *'), findsNothing);
  });

  testWidgets('manual game form requires a title before saving', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: GameFormScreen())),
    );
    final saveButton = find.text('Salvar jogo');
    await tester.scrollUntilVisible(
      saveButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('Informe o nome do jogo.'), findsOneWidget);
    expect(find.text('Catálogo RAWG'), findsOneWidget);
  });

  testWidgets(
    'catalog without a key reports the setup hint and keeps manual form',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: GameFormScreen())),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Hades');
      await tester.tap(find.byTooltip('Pesquisar RAWG'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('RAWG_API_KEY não foi passada'),
        findsOneWidget,
      );
      expect(find.text('Nome do jogo *'), findsOneWidget);
      expect(find.text('Salvar jogo'), findsOneWidget);
    },
  );
}
