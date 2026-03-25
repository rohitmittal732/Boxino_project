import 'package:flutter/material.dart';

class AppTheme {
  // Soft orange and green as per requirement
  static const Color primaryOrange = Color(0xFFFF9B50);
  static const Color primaryGreen = Color(0xFF8FC0A9);
  
  static const Color background = Color(0xFFFAFAFA);

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
