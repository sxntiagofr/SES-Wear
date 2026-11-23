import 'package:material_ui/material_ui.dart';

/// Identidad visual de SES Wear, tomada del prototipo de Figma:
/// en modo oscuro, fondo morado casi negro y tarjetas morado oscuro; en modo
/// claro, fondo lila muy claro y tarjetas blancas. Botones morados y un acento
/// durazno (el «inteligente» del eslogan) en ambos.
///
/// Todas las pantallas usan estos colores, así que cambiar uno aquí lo cambia
/// en toda la app. Los que dependen del modo son getters: leen [oscuro], que
/// fija `ControladorTema` (core/theme/controlador_tema.dart).
class AppTheme {
  AppTheme._();

  /// Modo activo. Lo cambia `ControladorTema`; no modificarlo directamente.
  static bool oscuro = true;

  // Marca (igual en los dos modos)
  static const Color primary = Color(0xFF7550E6);
  static const Color primaryDark = Color(0xFF5B37C9);
  static const Color success = Color(0xFF4CAF86);

  static Color get accent => oscuro ? const Color(0xFFF4B8A6) : const Color(0xFFD0704F);
  static Color get link => oscuro ? const Color(0xFF9B7BFF) : const Color(0xFF5B37C9);

  /// Fondo de íconos, chips y estados seleccionados (morado tenue).
  static Color get primaryLight => oscuro ? const Color(0xFF2E2252) : const Color(0xFFEDE7FF);

  // Superficies
  static Color get background => oscuro ? const Color(0xFF120A24) : const Color(0xFFF7F5FC);
  static Color get surface => oscuro ? const Color(0xFF1E1538) : const Color(0xFFFFFFFF);
  static Color get border => oscuro ? const Color(0xFF34295C) : const Color(0xFFE2DCF0);

  // Texto
  static Color get textPrimary => oscuro ? const Color(0xFFF5F3FA) : const Color(0xFF1B1530);
  static Color get textSecondary => oscuro ? const Color(0xFFA39DB8) : const Color(0xFF625C7A);

  // Estados
  static Color get error => oscuro ? const Color(0xFFFF8A8A) : const Color(0xFFC62828);

  /// Fondo de los mensajes de error (SnackBar).
  static Color get fondoError => oscuro ? const Color(0xFF3A1626) : const Color(0xFFFDE4E8);

  /// Degradado rosa → lila de los botones principales (boceto de diseño).
  static const degradado = LinearGradient(
    colors: [Color(0xFFE48AD4), Color(0xFF9470F2)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Fondo de los encabezados: brillo morado arriba que se funde con el fondo.
  static LinearGradient get degradadoEncabezado => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: oscuro
            ? const [Color(0xFF3A1F6B), Color(0xFF120A24)]
            : const [Color(0xFFE6DAFF), Color(0xFFF7F5FC)],
      );

  /// Fondo de las fotos de prendas (blanco, como en el boceto).
  static const fondoPrenda = Colors.white;

  static const double radioCampo = 16;
  static const double radioBoton = 28;

  static ThemeData get theme {
    final brillo = oscuro ? Brightness.dark : Brightness.light;
    final esquema = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brillo,
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
      borderSide: BorderSide(color: border),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brillo,
      colorScheme: esquema,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
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
        hintStyle: TextStyle(color: textSecondary),
        labelStyle: TextStyle(color: textSecondary),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
        border: bordeCampo,
        enabledBorder: bordeCampo,
        focusedBorder: bordeCampo.copyWith(
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: bordeCampo.copyWith(
          borderSide: BorderSide(color: error),
        ),
        focusedErrorBorder: bordeCampo.copyWith(
          borderSide: BorderSide(color: error, width: 1.5),
        ),
        errorStyle: TextStyle(color: error),
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
        side: BorderSide(color: textSecondary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surface,
        contentTextStyle: TextStyle(color: textPrimary),
      ),
      dialogTheme: DialogThemeData(backgroundColor: surface),
      dividerTheme: DividerThemeData(color: border, thickness: 1),
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
            return TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: link);
          }
          return TextStyle(fontSize: 12, color: textSecondary);
        }),
      ),
    );
  }
}
