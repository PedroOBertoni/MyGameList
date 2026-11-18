import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/app_providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MyGameListApp()));
}

class MyGameListApp extends ConsumerWidget {
  const MyGameListApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
