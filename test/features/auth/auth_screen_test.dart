import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_game_list/core/theme/app_theme.dart';
import 'package:my_game_list/features/auth/auth_screen.dart';

void main() {
  testWidgets('login validates email format and required password', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.dark(), home: const LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final submit = find.widgetWithText(FilledButton, 'Entrar');
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('Informe seu e-mail.'), findsOneWidget);
    expect(find.text('Informe sua senha.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'nao-e-email');
    await tester.enterText(find.byType(TextFormField).at(1), 'senha');
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('Informe um e-mail válido.'), findsOneWidget);
    expect(find.text('Informe sua senha.'), findsNothing);
  });

  testWidgets('registration screen fits a narrow phone viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const RegisterScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Criar conta'), findsWidgets);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });

  testWidgets('password strength reacts and confirmation validates live', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const RegisterScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Muito fraca'), findsNothing);
    await tester.enterText(find.byType(TextFormField).at(1), 'abc123!');
    await tester.pumpAndSettle();
    expect(find.text('Média'), findsOneWidget);
    expect(find.text('Mín. 8'), findsOneWidget);
    expect(find.text('Letra'), findsOneWidget);
    expect(find.text('Número'), findsOneWidget);
    expect(find.text('Símbolo'), findsOneWidget);
    expect(find.text('As senhas não coincidem.'), findsNothing);

    await tester.enterText(find.byType(TextFormField).at(2), 'abc123?');
    await tester.pumpAndSettle();
    expect(find.text('As senhas não coincidem.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(2), 'abc123!');
    await tester.pumpAndSettle();
    expect(find.text('As senhas não coincidem.'), findsNothing);

    await tester.enterText(find.byType(TextFormField).at(1), 'abc123!A');
    await tester.pumpAndSettle();
    expect(find.text('Muito forte'), findsOneWidget);
  });
}
