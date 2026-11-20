import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:my_game_list/core/models/game.dart';
import 'package:my_game_list/core/providers/app_providers.dart';
import 'package:my_game_list/core/router/app_router.dart';
import 'package:my_game_list/core/theme/app_theme.dart';
import 'package:my_game_list/core/widgets/app_bottom_navigation.dart';

void main() {
  testWidgets('three tabs work and Add starts in the selected list', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    final now = DateTime.utc(2025);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStatusProvider.overrideWithValue(const AsyncData(true)),
          gamesProvider.overrideWith(
            (ref, listType) async => [
              Game(
                id: listType.name,
                name: 'Sample game',
                platformId: 'pc',
                listType: listType,
                createdAt: now,
                updatedAt: now,
              ),
            ],
          ),
          listPreferencesProvider.overrideWith(
            (ref, listType) async => const ListPreferences(
              sortMode: GameSortMode.manual,
              tieOrders: {},
            ),
          ),
          pendingOperationCountProvider.overrideWith((ref) async => 0),
        ],
        child: const _RouterApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Minha Biblioteca'), findsOneWidget);
    expect(find.text('Adicionar'), findsNothing);
    expect(find.text('Perfil'), findsOneWidget);

    await tester.tap(find.text('Desejos'));
    await tester.pumpAndSettle();
    expect(find.text('Lista de Desejos'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Adicionar jogo'), findsOneWidget);
    expect(find.text('Lista de desejos'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Lista de Desejos'), findsOneWidget);

    await tester.tap(find.text('Biblioteca'));
    await tester.pumpAndSettle();
    expect(find.text('Minha Biblioteca'), findsOneWidget);
  });

  testWidgets('unauthenticated sessions cannot open protected routes', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [authStatusProvider.overrideWithValue(const AsyncData(false))],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _RouterApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Acesse sua conta para entrar na sua biblioteca'),
      findsOneWidget,
    );
    expect(find.byType(AppBottomNavigation), findsNothing);

    container.read(routerProvider).go('/settings');
    await tester.pumpAndSettle();
    expect(
      find.text('Acesse sua conta para entrar na sua biblioteca'),
      findsOneWidget,
    );
    expect(find.text('Perfil e configurações'), findsNothing);
  });

  testWidgets('bottom navigation selects each of its three destinations', (
    tester,
  ) async {
    var selectedIndex = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            bottomNavigationBar: AppBottomNavigation(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) =>
                  setState(() => selectedIndex = index),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Biblioteca'), findsOneWidget);
    expect(find.text('Desejos'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
    expect(find.text('Adicionar'), findsNothing);

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(selectedIndex, 2);
    expect(
      tester.widget<Text>(find.text('Perfil')).style?.color,
      AppColors.gold,
    );
  });
}

class _RouterApp extends ConsumerWidget {
  const _RouterApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    theme: AppTheme.dark(),
    routerConfig: ref.watch(routerProvider),
  );
}
