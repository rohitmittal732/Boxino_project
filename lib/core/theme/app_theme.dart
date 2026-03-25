import 'package:flutter/material.dart';

class AppTheme {
  // ── Brand Colors ─────────────────────────────────────────────
  static const Color primaryOrange = Color(0xFFFF9B50);
  static const Color primaryGreen  = Color(0xFF6DBF8B);
  static const Color deepOrange    = Color(0xFFFF6B2B);
  static const Color softGreen     = Color(0xFF8FC0A9);
  static const Color background    = Color(0xFFF7F8FA);
  static const Color cardWhite     = Color(0xFFFFFFFF);
  static const Color textDark      = Color(0xFF1A1A2E);
  static const Color textGrey      = Color(0xFF7A7A9D);
  static const Color errorRed      = Color(0xFFFF4757);

  // ── Gradients ────────────────────────────────────────────────
  static const LinearGradient gradientOrangeGreen = LinearGradient(
    colors: [deepOrange, primaryOrange, primaryGreen],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient gradientGreenOrange = LinearGradient(
    colors: [primaryGreen, primaryOrange, deepOrange],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient gradientHeaderOrange = LinearGradient(
    colors: [Color(0xFFFF6B2B), Color(0xFFFF9B50)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient gradientHeaderGreen = LinearGradient(
    colors: [Color(0xFF4CAF7D), Color(0xFF8FC0A9)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── Shadows ──────────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.07),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get buttonShadow => [
    BoxShadow(
      color: primaryOrange.withOpacity(0.35),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  // ── Theme Data ───────────────────────────────────────────────
  static final ThemeData lightTheme = ThemeData(
    primaryColor: primaryOrange,
    scaffoldBackgroundColor: background,
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: primaryOrange,
      secondary: primaryGreen,
      error: errorRed,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold,   color: textDark, height: 1.2),
      headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,  color: textDark),
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,      color: textDark),
      bodyMedium: TextStyle(fontSize: 14, color: textGrey, height: 1.5),
      labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,      color: Colors.white),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primaryOrange, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: errorRed),
      ),
      hintStyle: const TextStyle(color: textGrey, fontSize: 14),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
