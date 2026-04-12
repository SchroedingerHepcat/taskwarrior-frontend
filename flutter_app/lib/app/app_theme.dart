import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const canvas = Color(0xFFF5F1E8);
  const ink = Color(0xFF16343F);
  const accent = Color(0xFFCB5D39);
  const muted = Color(0xFF5E756A);
  const surface = Color(0xFFFFFCF7);

  final scheme = ColorScheme.fromSeed(
    seedColor: ink,
    brightness: Brightness.light,
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
    appBarTheme: const AppBarTheme(
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
