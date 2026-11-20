import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/app_providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var firebaseInitialized = false;
  try {
    await Firebase.initializeApp();
    firebaseInitialized = true;
  } catch (error) {
    debugPrint('Firebase não foi inicializado neste dispositivo: $error');
  }

  runApp(
    ProviderScope(
      overrides: [
        firebaseInitializedProvider.overrideWithValue(firebaseInitialized),
      ],
      child: const MyGameListApp(),
    ),
  );
}

class MyGameListApp extends ConsumerWidget {
  const MyGameListApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(authStateProvider, (previous, next) {
      next.whenData((user) {
        if (user != null) {
          unawaited(
            syncCurrentAccountFromWidgetRef(ref, user: user).catchError((
              Object error,
            ) {
              debugPrint('Falha ao sincronizar dados Firebase: $error');
            }),
          );
        }
      });
    });
    final router = ref.watch(routerProvider);
    final theme = ref.watch(themeControllerProvider);
    return ListenableBuilder(
      listenable: theme,
      builder: (context, _) => MaterialApp.router(
        title: 'MyGameList',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: theme.mode,
        routerConfig: router,
      ),
    );
  }
}
