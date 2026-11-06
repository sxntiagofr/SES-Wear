import 'package:flutter/material.dart';

class AppTheme {
  // Identidad visual SES Wear
  static const Color primary = Color(0xFF7950D8);
  static const Color primaryDark = Color(0xFF5E35B1);
  static const Color primaryLight = Color(0xFFEDE5FF);

  static const Color background = Color(0xFFFAF8FF);
  static const Color surface = Color(0xFFFFFFFF);

  static const Color textPrimary = Color(0xFF292333);
  static const Color textSecondary = Color(0xFF817B8C);

  static const Color success = Color(0xFF4CAF86);
  static const Color error = Color(0xFFE57373);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: primaryLight,
        surface: surface,
        error: error,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primaryLight,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: primary,
            );
          }

          return const TextStyle(fontSize: 12, color: textSecondary);
        }),
      ),
    );
  }
}
