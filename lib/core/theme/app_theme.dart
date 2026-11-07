import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Soft morning-home palette: cool mist + sage teal + lamp amber.
/// Avoids purple gradients, cream+terracotta, and flat gray dashboards.
class AppColors {
  static const mistTop = Color(0xFFD9E6EE);
  static const mistBottom = Color(0xFFEEF3F6);
  static const ink = Color(0xFF14212B);
  static const inkSoft = Color(0xFF3A4A55);
  static const sage = Color(0xFF1F6B63);
  static const sageDeep = Color(0xFF15554F);
  static const amber = Color(0xFFC9782A);
  static const surface = Color(0xF2FFFFFF);
  static const line = Color(0x3314212B);
  static const danger = Color(0xFFB42318);
  static const ok = Color(0xFF1B7A4E);
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.mistBottom,
      colorScheme: const ColorScheme.light(
        primary: AppColors.sage,
        onPrimary: Colors.white,
        secondary: AppColors.amber,
        onSecondary: Colors.white,
        surface: Colors.white,
        onSurface: AppColors.ink,
        error: AppColors.danger,
      ),
    );

    final display = GoogleFonts.outfitTextTheme(base.textTheme).apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    );
    final body = GoogleFonts.figtreeTextTheme(display);

    return base.copyWith(
      textTheme: body.copyWith(
        displayLarge: body.displayLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -1.2,
        ),
        headlineMedium: body.headlineMedium?.copyWith(
          fontFamily: GoogleFonts.outfit().fontFamily,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
        ),
        titleLarge: body.titleLarge?.copyWith(
          fontFamily: GoogleFonts.outfit().fontFamily,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: body.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.ink,
        titleTextStyle: GoogleFonts.outfit(
          color: AppColors.ink,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.72),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.sage, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.sage,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.figtree(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: GoogleFonts.figtree(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
