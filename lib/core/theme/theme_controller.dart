import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.dark;
  bool _disposed = false;
  bool _changedByUser = false;

  ThemeController() {
    unawaited(_load());
  }

  ThemeMode get mode => _mode;

  Future<void> _load() async {
    final preferences = SharedPreferencesAsync();
    final stored = await preferences.getString('appearance.theme_mode');
    if (_disposed || _changedByUser || stored == null) return;
    _mode = stored == 'light' ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    _changedByUser = true;
    _mode = mode;
    notifyListeners();
    await SharedPreferencesAsync().setString(
      'appearance.theme_mode',
      mode == ThemeMode.light ? 'light' : 'dark',
    );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
