import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_game_list/features/games/game_form_screen.dart';

void main() {
  testWidgets('manual form fits a narrow phone screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: GameFormScreen())),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
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

      expect(find.textContaining('Chave RAWG ausente'), findsOneWidget);
      expect(find.text('Nome do jogo *'), findsOneWidget);
      expect(find.text('Salvar jogo'), findsOneWidget);
    },
  );
}
