import 'package:flutter/material.dart';

class AppTheme {
  // Industrial Colors
  static const Color primary = Color(0xFFF59E0B); // Amber
  static const Color primaryVariant = Color(0xFFD97706); // Darker Amber
  static const Color background = Color(0xFF0A0A0A); // Very dark gray/black
  static const Color surface = Color(0xFF111111); // Slightly lighter than background
  static const Color surfaceLight = Color(0xFF1A1A1A); // Lighter surface for cards
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFAAAAAA);
  static const Color border = Color(0xFF333333);
  static const Color error = Color(0xFFEF4444); // Red

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      cardColor: surface,
      dividerColor: border,
      fontFamily: 'Inter',
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: primaryVariant,
        background: background,
        surface: surface,
        error: error,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 32),
        displayMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 24),
        bodyLarge: TextStyle(color: textPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 14),
        labelLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, letterSpacing: 1.2), // Uppercase vibe
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: primary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
      cardTheme: const CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)), // Hard edges
          side: BorderSide(color: border, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: background, // Black text on amber button
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal, fontSize: 10),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero, // No rounded corners for bottom sheet
          side: BorderSide(color: border, width: 1),
        ),
      ),
    );
  }
}
