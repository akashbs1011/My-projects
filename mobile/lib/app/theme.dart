import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The visual system: a light clinical surface, one teal accent used sparingly,
/// and amber/clay reserved exclusively for caution and urgency so those colours
/// never appear as decoration.
class AppTheme {
  const AppTheme._();

  static const Color clinical = Color(0xFF0E7C86);
  static const Color clinicalDark = Color(0xFF0B6169);
  static const Color clinicalLight = Color(0xFFEDF7F8);
  static const Color clinicalBorder = Color(0xFFD3ECEE);

  static const Color ink = Color(0xFF0F1E2E);
  static const Color inkSoft = Color(0xFF3D4F60);
  static const Color inkMuted = Color(0xFF6B7C8C);

  static const Color mist = Color(0xFFF4F7FA);
  static const Color line = Color(0xFFE2E8F0);

  static const Color cautionBg = Color(0xFFFDF4EC);
  static const Color cautionBorder = Color(0xFFF0C9A4);
  static const Color cautionText = Color(0xFF8A4B18);

  static const Color alertBg = Color(0xFFFDF1EE);
  static const Color alertBorder = Color(0xFFF0BCAE);
  static const Color alertText = Color(0xFF9B3B1C);

  static const double radius = 14;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: clinical,
      brightness: Brightness.light,
    ).copyWith(
      primary: clinical,
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: ink,
      error: alertText,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: mist,
      splashFactory: InkRipple.splashFactory,

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),

      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: line),
        ),
      ),

      // Numeric labels use a monospace face with tabular figures so two scores
      // can be compared down a column without the digits shifting.
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontSize: 24, fontWeight: FontWeight.w600, color: ink, letterSpacing: -0.4,
        ),
        titleLarge: TextStyle(
          fontSize: 19, fontWeight: FontWeight.w600, color: ink, letterSpacing: -0.2,
        ),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ink),
        bodyLarge: TextStyle(fontSize: 15, height: 1.5, color: ink),
        bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: inkSoft),
        bodySmall: TextStyle(fontSize: 12.5, height: 1.45, color: inkMuted),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        labelSmall: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600,
          color: inkMuted, letterSpacing: 0.6,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: _border(line),
        enabledBorder: _border(line),
        focusedBorder: _border(clinical, width: 1.6),
        errorBorder: _border(alertBorder),
        focusedErrorBorder: _border(alertText, width: 1.6),
        hintStyle: const TextStyle(color: inkMuted, fontSize: 14.5),
        labelStyle: const TextStyle(color: inkSoft, fontSize: 14),
        errorStyle: const TextStyle(color: alertText, fontSize: 12.5),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: clinical,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(0, 48),
          side: const BorderSide(color: line),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: clinicalDark),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: clinicalLight,
        elevation: 3,
        height: 66,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11.5,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? clinicalDark : inkMuted,
          ),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: clinicalLight,
        side: const BorderSide(color: clinicalBorder),
        labelStyle: const TextStyle(
          color: clinicalDark, fontSize: 13.5, fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 1),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: clinical),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      ),
    );
  }

  static OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: BorderSide(color: color, width: width),
      );

  /// Monospace, tabular style for scores, counts and dates.
  static const TextStyle stat = TextStyle(
    fontFamily: 'monospace',
    fontFeatures: [FontFeature.tabularFigures()],
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: ink,
  );
}
