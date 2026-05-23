// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : app_theme.dart
// Description   : App theme configuration for FYP Neobanking.
//                 Defines colours, typography, and component styles.
// First Written : 21-May-2026
// Edited on     : 21-May-2026
// ============================================

import 'package:flutter/material.dart';

class AppTheme {
  // Primary colours
  static const Color primaryColor = Color(0xFF1A73E8);
  static const Color secondaryColor = Color(0xFF34A853);
  static const Color accentColor = Color(0xFFFBBC04);
  static const Color errorColor = Color(0xFFEA4335);

  // Vault colours
  static const Color vaultGreen = Color(0xFF4CAF50);
  static const Color vaultBlue = Color(0xFF2196F3);
  static const Color vaultOrange = Color(0xFFFF9800);
  static const Color vaultRed = Color(0xFFF44336);
  static const Color vaultPurple = Color(0xFF9C27B0);
  static const Color vaultTeal = Color(0xFF009688);

  // Background colours
  static const Color backgroundColor = Color(0xFFF8F9FA);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color cardColor = Color(0xFFFFFFFF);

  // Text colours
  static const Color textPrimary = Color(0xFF202124);
  static const Color textSecondary = Color(0xFF5F6368);
  static const Color textHint = Color(0xFF9AA0A6);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceColor,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
      ),
      fontFamily: 'Roboto',
    );
  }
}