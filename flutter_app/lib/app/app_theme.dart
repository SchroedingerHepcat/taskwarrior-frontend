import 'package:flutter/material.dart';

enum AppThemePreference {
  dark('Dark', ThemeMode.dark),
  light('Light', ThemeMode.light),
  system('System', ThemeMode.system);

  const AppThemePreference(
    this.label,
    this.themeMode,
  );

  final String label;
  final ThemeMode themeMode;

  static AppThemePreference fromStorage(String? value) {
    return AppThemePreference.values.firstWhere(
      (preference) => preference.name == value,
      orElse: () => AppThemePreference.dark,
    );
  }
}

ThemeData buildLightAppTheme() {
  return _buildAppTheme(
    brightness: Brightness.light,
    canvas: const Color(0xFFF5F1E8),
    ink: const Color(0xFF16343F),
    accent: const Color(0xFFCB5D39),
    muted: const Color(0xFF5E756A),
    surface: const Color(0xFFFFFCF7),
  );
}

ThemeData buildDarkAppTheme() {
  return _buildAppTheme(
    brightness: Brightness.dark,
    canvas: const Color(0xFF121A1D),
    ink: const Color(0xFFE6F1EF),
    accent: const Color(0xFFE38C66),
    muted: const Color(0xFF9EB8AD),
    surface: const Color(0xFF1B262A),
  );
}

ThemeData _buildAppTheme({
  required Brightness brightness,
  required Color canvas,
  required Color ink,
  required Color accent,
  required Color muted,
  required Color surface,
}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: ink,
    brightness: brightness,
  ).copyWith(
    primary: ink,
    secondary: accent,
    tertiary: muted,
    surface: surface,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: canvas,
    fontFamily: 'sans-serif',
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        height: 1.05,
      ),
      titleLarge: TextStyle(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: TextStyle(
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: TextStyle(
        height: 1.35,
      ),
      bodyMedium: TextStyle(
        height: 1.35,
      ),
      labelLarge: TextStyle(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: ink,
      centerTitle: false,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: ink.withValues(alpha: 0.08),
      selectedColor: accent.withValues(alpha: 0.18),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      shadowColor: ink.withValues(alpha: 0.08),
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
    ),
  );
}
