import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/games/game_detail_screen.dart';
import '../../features/games/game_form_screen.dart';
import '../../features/auth/auth_screen.dart';
import '../../features/auth/legal_document_screen.dart';
import '../../features/library/game_list_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../models/game.dart';
import '../providers/app_providers.dart';
import '../widgets/app_bottom_navigation.dart';

final routerProvider = Provider<GoRouter>((ref) {
  late final GoRouter router;
  router = GoRouter(
    initialLocation: '/auth/checking',
    redirect: (context, state) {
      const publicRoutes = {
        '/auth/checking',
        '/login',
        '/register',
        '/terms',
        '/privacy',
      };
      const signedInLandingRoutes = {'/auth/checking', '/login', '/register'};
      final location = state.uri.path;
      final authStatus = ref.read(authStatusProvider);

      if (authStatus.isLoading) {
        return location == '/auth/checking' ? null : '/auth/checking';
      }

      final isSignedIn = authStatus.asData?.value ?? false;
      if (!isSignedIn && location == '/auth/checking') return '/login';
      if (!isSignedIn && !publicRoutes.contains(location)) return '/login';
      if (isSignedIn && signedInLandingRoutes.contains(location)) {
        return '/library';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', redirect: (context, state) => '/auth/checking'),
      GoRoute(
        path: '/auth/checking',
        builder: (context, state) => const AuthLoadingScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/terms',
        builder: (context, state) =>
            const LegalDocumentScreen(document: LegalDocument.terms),
      ),
      GoRoute(
        path: '/privacy',
        builder: (context, state) =>
            const LegalDocumentScreen(document: LegalDocument.privacy),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                builder: (context, state) =>
                    const GameListScreen(listType: GameListType.library),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/wishlist',
                builder: (context, state) =>
                    const GameListScreen(listType: GameListType.wishlist),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/add',
        builder: (context, state) => GameFormScreen(
          initialListType:
              state.uri.queryParameters['list'] == GameListType.wishlist.name
              ? GameListType.wishlist
              : GameListType.library,
        ),
      ),
      GoRoute(
        path: '/games/:id',
        builder: (context, state) =>
            GameDetailScreen(gameId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/games/:id/edit',
        builder: (context, state) =>
            GameFormScreen(gameId: state.pathParameters['id']),
      ),
    ],
  );
  ref.listen(authStatusProvider, (previous, next) => router.refresh());
  ref.onDispose(router.dispose);
  return router;
});

class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: navigationShell,
    bottomNavigationBar: AppBottomNavigation(
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: (index) => navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      ),
    ),
  );
}
