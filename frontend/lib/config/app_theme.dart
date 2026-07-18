// ============================================
// Programmer    : Lau Zheng Cheng (TP071393)
// Program Name  : app_theme.dart
// Description   : Dark Hermès-inspired warm gold theme for FinWise.
//                 Gold = warm amber cognac (not bright yellow).
//                 All backgrounds are warm black (no blue tint).
//                 backgroundGradient = dark amber top → warm black bottom.
// First Written : 21-May-2026
// Edited on     : 10-06-2026
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // ── Gold palette (Hermès amber — aged leather hardware, not jewelry) ──
  static const Color primaryColor   = Color(0xFFC49235); // Hermès amber gold
  static const Color goldDeep       = Color(0xFF7A5A18); // deep cognac gold
  static const Color goldBright     = Color(0xFFE8B84B); // warm highlight
  static const Color accentColor    = Color(0xFFC49235); // alias

  // ── Silver palette (warm tone — no blue tint) ─────────────────────────
  static const Color secondaryColor = Color(0xFFB8B0A0); // warm silver
  static const Color silverMuted    = Color(0xFF787060); // warm inactive gray

  // ── Backgrounds (warm black — no blue tint) ───────────────────────────
  static const Color backgroundColor = Color(0xFF080706); // warm near-black
  static const Color surfaceColor    = Color(0xFF15130F); // warm dark surface
  static const Color cardColor       = Color(0xFF1E1B14); // warm elevated card

  // ── Glass ─────────────────────────────────────────────────────────────
  static const Color glassColor       = Color(0x1AFFFFFF); // ~10% white
  static const Color glassBorderColor = Color(0x14FFFFFF); // ~8% white

  // ── Text (warm tone — no blue tint) ───────────────────────────────────
  static const Color textPrimary   = Color(0xFFEEEDE8); // warm near-white
  static const Color textSecondary = Color(0xFFA09888); // warm silver-gray
  static const Color textHint      = Color(0xFF5C5448); // warm dim hint

  // ── Functional ────────────────────────────────────────────────────────
  static const Color errorColor   = Color(0xFFFF4D6A);
  static const Color successColor = Color(0xFF4ADE80);

  // ── Vault accent palette ──────────────────────────────────────────────
  static const Color vaultGreen  = Color(0xFF4ADE80);
  static const Color vaultBlue   = Color(0xFF5090E0);
  static const Color vaultOrange = Color(0xFFC49235); // matches gold
  static const Color vaultRed    = Color(0xFFFF4D6A);
  static const Color vaultPurple = Color(0xFF9080D0);
  static const Color vaultTeal   = Color(0xFF40B8A0);

  // ── Gradients ─────────────────────────────────────────────────────────

  // Full-screen warm background — dark amber glow at top fading to warm black
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF231408), // dark warm amber at top
      Color(0xFF100A05), // transition
      Color(0xFF060504), // near-pure warm black
    ],
    stops: [0.0, 0.30, 0.70],
  );

  // Gold gradient for buttons and accents
  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFF7A5A18), Color(0xFFC49235), Color(0xFFE8B84B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient subtleGoldGradient = LinearGradient(
    colors: [Color(0xFF1E1B14), Color(0xFF1C1608)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Glass card decoration ──────────────────────────────────────────────
  static BoxDecoration glassCard({
    double radius = 20,
    bool goldBorder = false,
    bool elevated = false,
  }) {
    return BoxDecoration(
      color: elevated ? cardColor : const Color(0x14FFFFFF),
      borderRadius: BorderRadius.circular(radius),
      border: goldBorder
          ? Border.all(
              color: primaryColor.withValues(alpha: 0.35),
              width: 1,
            )
          : null,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.50),
          blurRadius: elevated ? 20 : 12,
          offset: const Offset(0, 4),
        ),
        if (goldBorder)
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.08),
            blurRadius: 24,
            spreadRadius: 2,
          ),
      ],
    );
  }

  // ── Theme ──────────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        onPrimary: Color(0xFF080706),
        secondary: secondaryColor,
        onSecondary: Color(0xFF080706),
        surface: surfaceColor,
        onSurface: textPrimary,
        error: errorColor,
        onError: Colors.white,
        surfaceContainerHighest: cardColor,
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceColor,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: glassBorderColor, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: const Color(0xFF080706),
          minimumSize: const Size(double.infinity, 52),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          minimumSize: const Size(double.infinity, 52),
          side: const BorderSide(color: primaryColor, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: glassBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: glassBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: errorColor),
        ),
        hintStyle: const TextStyle(color: textHint, fontSize: 15),
        labelStyle: const TextStyle(color: textSecondary),
        prefixIconColor: textSecondary,
      ),
      dividerTheme: const DividerThemeData(
        color: glassBorderColor,
        space: 0,
      ),
      bottomAppBarTheme: const BottomAppBarThemeData(
        color: surfaceColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Color(0xFF080706),
        elevation: 6,
        shape: CircleBorder(),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cardColor,
        contentTextStyle: const TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryColor,
      ),
      textTheme: const TextTheme(
        displayLarge:   TextStyle(color: textPrimary,   fontWeight: FontWeight.w300),
        displayMedium:  TextStyle(color: textPrimary,   fontWeight: FontWeight.w300),
        headlineLarge:  TextStyle(color: textPrimary,   fontWeight: FontWeight.w700),
        headlineMedium: TextStyle(color: textPrimary,   fontWeight: FontWeight.w600),
        titleLarge:     TextStyle(color: textPrimary,   fontWeight: FontWeight.w600),
        titleMedium:    TextStyle(color: textPrimary,   fontWeight: FontWeight.w500),
        titleSmall:     TextStyle(color: textSecondary, fontWeight: FontWeight.w400),
        bodyLarge:      TextStyle(color: textPrimary),
        bodyMedium:     TextStyle(color: textPrimary),
        bodySmall:      TextStyle(color: textSecondary),
        labelLarge:     TextStyle(color: textPrimary,   fontWeight: FontWeight.w600),
        labelMedium:    TextStyle(color: textSecondary),
        labelSmall:     TextStyle(color: textHint,      letterSpacing: 0.5),
      ),
    );
  }
}
