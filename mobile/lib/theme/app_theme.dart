import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Professional PowerBid Color Palette: Gold, Silver, and Electric-Blue accents
  static const Color background = Color(0xFF0A0D14);
  static const Color surface = Color(0xFF131926);
  static const Color surfaceLight = Color(0xFF1F293D);
  static const Color primary = Color(0xFF00B0FF);      // Electric Blue
  static const Color electricBlue = Color(0xFF00E5FF);  // Vibrant Cyan/Blue Accent
  static const Color accent = Color(0xFFFFD700);       // Polished Gold Accent
  static const Color gold = Color(0xFFFFD700);         // Metallic Gold
  static const Color silver = Color(0xFFCBD5E1);       // Polished Silver
  static const Color silverLight = Color(0xFFF1F5F9);  // Bright Platinum Silver
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color error = Color(0xFFFF5252);
  static const Color success = Color(0xFF00E676);
  static const Color warning = Color(0xFFFFB300);

  static ThemeData get darkTheme {
    final baseDark = ThemeData.dark();
    final textTheme = GoogleFonts.outfitTextTheme(baseDark.textTheme).apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );

    return baseDark.copyWith(
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      textTheme: textTheme,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: surface,
        error: error,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 4,
        shadowColor: Colors.black45,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: surfaceLight, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        hintStyle: const TextStyle(color: textSecondary),
        labelStyle: const TextStyle(color: accent),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          side: const BorderSide(color: accent, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData.light().copyWith(
      scaffoldBackgroundColor: const Color(0xFFF4F4F8),
      primaryColor: const Color(0xFF673AB7),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF673AB7),
        secondary: Color(0xFF0091EA),
        surface: Colors.white,
        error: error,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Color(0xFF1A1A24),
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: Color(0xFF1A1A24)),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF0F0F5),
        hintStyle: const TextStyle(color: Color(0xFF757575)),
        labelStyle: const TextStyle(color: Color(0xFF673AB7)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF673AB7), width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF673AB7),
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
