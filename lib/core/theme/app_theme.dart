import 'package:material_ui/material_ui.dart';

abstract final class AppColors {
  static const ink = Color(0xFF080D17);
  static const navy = Color(0xFF101B30);
  static const blue = Color(0xFF233D65);
  static const gold = Color(0xFFF5C542);
  static const white = Color(0xFFF8FAFC);
  static const muted = Color(0xFF8D9AAF);
  static const green = Color(0xFF55C6A2);
  static const red = Color(0xFFFF7B78);
  static const playingBlue = Color(0xFF68B7FF);
  static const goldOnLight = Color(0xFF8A6500);

  static Color accent(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? gold : goldOnLight;
}

abstract final class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const radius = 20.0;
  static const buttonRadius = 14.0;
  static const primaryButtonHeight = 52.0;
  static const primaryButtonPadding = EdgeInsets.symmetric(
    horizontal: 24,
    vertical: 12,
  );
  static const buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(buttonRadius)),
  );
}

abstract final class AppTheme {
  static ButtonStyle primaryActionButtonStyle() => FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(AppSpace.primaryButtonHeight),
    padding: AppSpace.primaryButtonPadding,
    shape: AppSpace.buttonShape,
  );

  static ButtonStyle outlinedActionButtonStyle(
    BuildContext context, {
    Color? color,
  }) {
    final accent = color ?? Theme.of(context).colorScheme.primary;
    return OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(AppSpace.primaryButtonHeight),
      padding: AppSpace.primaryButtonPadding,
      shape: AppSpace.buttonShape,
      foregroundColor: accent,
      side: BorderSide(color: accent),
    );
  }

  static ThemeData dark() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.gold,
      onPrimary: AppColors.ink,
      secondary: AppColors.blue,
      onSecondary: AppColors.white,
      error: AppColors.red,
      onError: AppColors.ink,
      surface: AppColors.navy,
      onSurface: AppColors.white,
      onSurfaceVariant: AppColors.muted,
      outlineVariant: AppColors.blue,
    );
    return _build(scheme, AppColors.ink);
  }

  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.goldOnLight,
      onPrimary: AppColors.white,
      secondary: AppColors.blue,
      onSecondary: AppColors.white,
      error: Color(0xFFB3261E),
      onError: AppColors.white,
      surface: Colors.white,
      onSurface: AppColors.ink,
      onSurfaceVariant: Color(0xFF58677C),
      outlineVariant: Color(0xFFD5DDE8),
    );
    return _build(scheme, const Color(0xFFF3F6FA));
  }

  static ThemeData _build(ColorScheme scheme, Color background) => ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: scheme.onSurface,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 22,
        fontWeight: FontWeight.w800,
      ),
      iconTheme: IconThemeData(color: scheme.primary),
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpace.radius / 1.5),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpace.radius / 1.5),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpace.radius / 1.5),
        borderSide: BorderSide(color: scheme.primary, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: AppSpace.buttonShape),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(shape: AppSpace.buttonShape),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: AppSpace.buttonShape),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(shape: AppSpace.buttonShape),
    ),
    chipTheme: ChipThemeData(
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
      labelStyle: TextStyle(color: scheme.onSurface),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primary.withValues(alpha: .16),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: .5),
    ),
  );
}
