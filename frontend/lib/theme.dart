import 'package:flutter/material.dart';

class AppColors {
  static const darkGreen = Color(0xFF2D5016);
  static const midGreen = Color(0xFF4A7A28);
  static const lightGreen = Color(0xFF7AAF4E);
  static const statusGreen = Color(0xFF3D6B1F);
  static const amber = Color(0xFFB5651D);
  static const background = Color(0xFFF5F0E8);
  static const cardWhite = Colors.white;
  static const textDark = Color(0xFF1A2E0A);
  static const textMid = Color(0xFF4A5A38);
  static const textLight = Color(0xFF6B7C5A);
  static const textHint = Color(0xFFB0B8A0);
  static const divider = Color(0xFFE0D8C8);
  static const riskHigh = Color(0xFFD32F2F);
  static const riskMed = Color(0xFFF57C00);
  static const riskLow = Color(0xFF388E3C);
}

class AppTheme {
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: AppColors.darkGreen,
      secondary: AppColors.midGreen,
      surface: AppColors.background,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
    ),
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'Georgia',
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 15),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.darkGreen,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    ),
  );
}