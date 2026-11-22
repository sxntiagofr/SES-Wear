import 'package:flutter/material.dart';

/// Identidad visual de SES Wear, tomada del prototipo de Figma:
/// fondo morado casi negro, tarjetas y campos morado oscuro, botones morados
/// y un acento durazno (el «inteligente» del eslogan).
///
/// Todas las pantallas usan estas constantes, así que cambiar un color aquí lo
/// cambia en toda la app.
class AppTheme {
  AppTheme._();

  // Marca
  static const Color primary = Color(0xFF7550E6);
  static const Color primaryDark = Color(0xFF5B37C9);
  static const Color accent = Color(0xFFF4B8A6);
  static const Color link = Color(0xFF9B7BFF);

  /// Fondo de íconos, chips y estados seleccionados (morado tenue).
  static const Color primaryLight = Color(0xFF2A2148);

  // Superficies
  static const Color background = Color(0xFF0C0916);
  static const Color surface = Color(0xFF17132A);
  static const Color border = Color(0xFF2B2542);

  // Texto
  static const Color textPrimary = Color(0xFFF5F3FA);
  static const Color textSecondary = Color(0xFFA39DB8);

  // Estados
  static const Color success = Color(0xFF4CAF86);
  static const Color error = Color(0xFFFF8A8A);

  static const double radioCampo = 16;
  static const double radioBoton = 28;

  static ThemeData get theme {
    final esquema = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: primary,
      onPrimary: Colors.white,
      secondary: accent,
      surface: surface,
      onSurface: textPrimary,
      error: error,
      outline: border,
    );

    final bordeCampo = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radioCampo),
      borderSide: const BorderSide(color: border),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: esquema,
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        hintStyle: const TextStyle(color: textSecondary),
        labelStyle: const TextStyle(color: textSecondary),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
        border: bordeCampo,
        enabledBorder: bordeCampo,
        focusedBorder: bordeCampo.copyWith(
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: bordeCampo.copyWith(
          borderSide: const BorderSide(color: error),
        ),
        focusedErrorBorder: bordeCampo.copyWith(
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
        errorStyle: const TextStyle(color: error),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: primary.withValues(alpha: 0.4),
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radioBoton),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: link),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? primary : Colors.transparent,
        ),
        side: const BorderSide(color: textSecondary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surface,
        contentTextStyle: TextStyle(color: textPrimary),
      ),
      dialogTheme: const DialogThemeData(backgroundColor: surface),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: background,
        indicatorColor: primaryLight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? link : textSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: link);
          }
          return const TextStyle(fontSize: 12, color: textSecondary);
        }),
      ),
    );
  }
}
