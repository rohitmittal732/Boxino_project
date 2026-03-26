import 'package:flutter/material.dart';

class AppTheme {
  // ── Brand colours ──────────────────────────────────────────
  static const Color primaryOrange = Color(0xFFFF9B50);
  static const Color deepOrange    = Color(0xFFFF6B2B);
  static const Color primaryGreen  = Color(0xFF8FC0A9);
  static const Color background    = Color(0xFFFAFAFA);

  // ── Text colours ───────────────────────────────────────────
  static const Color textDark = Color(0xFF1A1A2E);
  static const Color textGrey = Color(0xFF9E9E9E);

  // ── Feedback colours ───────────────────────────────────────
  static const Color errorRed = Color(0xFFFF4757);

  // ── Gradients ──────────────────────────────────────────────
  static const LinearGradient gradientOrangeGreen = LinearGradient(
    colors: [primaryOrange, primaryGreen],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // ── Shadows ────────────────────────────────────────────────
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x26000000), // ~15% opacity black
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> buttonShadow = [
    BoxShadow(
      color: Color(0x40FF9B50), // orange glow
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static final ThemeData lightTheme = ThemeData(
    primaryColor: primaryOrange,
    scaffoldBackgroundColor: background,
    useMaterial3: true,
    fontFamily: 'Inter', // Assuming Google Fonts Inter
    colorScheme: ColorScheme.light(
      primary: primaryOrange,
      secondary: primaryGreen,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 2, // soft shadow
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
  );
}
