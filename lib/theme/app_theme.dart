import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primary = Color(0xFF0060DF);
  static const Color primaryDark = Color(0xFF004AAE);
  static const Color surface = Color(0xFFF8F9F9);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFF191C1C);
  static const Color onSurfaceVariant = Color(0xFF4B5563);
  static const Color outline = Color(0xFFE5E7EB);
  static const Color error = Color(0xFFBA1A1A);
  static const Color success = Color(0xFF1B873F);
  static const Color warning = Color(0xFFB45309);

  static TextTheme _textTheme(Color base) => GoogleFonts.muktaTextTheme(
        TextTheme(
          displayLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: base, letterSpacing: -0.5),
          headlineLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: base),
          headlineMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: base),
          titleLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: base),
          titleMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: base),
          bodyLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: base, height: 1.5),
          bodyMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: base, height: 1.4),
          bodySmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: base.withOpacity(0.65)),
          labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: base),
          labelMedium: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: base, letterSpacing: 0.4),
          labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: base.withOpacity(0.65), letterSpacing: 0.3),
        ),
      );

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: primary,
          onPrimary: Colors.white,
          primaryContainer: Color(0xFFD9E2FF),
          surface: surface,
          onSurface: onSurface,
          surfaceContainerLow: Color(0xFFF3F4F4),
          surfaceContainer: surfaceCard,
          outline: outline,
          error: error,
        ),
        textTheme: _textTheme(onSurface),
        scaffoldBackgroundColor: surface,
        cardTheme: CardTheme(
          color: surfaceCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: outline),
          ),
          margin: EdgeInsets.zero,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: surfaceCard,
          foregroundColor: onSurface,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: GoogleFonts.mukta(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: onSurface,
          ),
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceCard,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: outline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: primary, width: 1.5),
          ),
          labelStyle: GoogleFonts.mukta(fontSize: 12, color: onSurfaceVariant),
          hintStyle: GoogleFonts.mukta(fontSize: 13, color: onSurfaceVariant),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
            textStyle: GoogleFonts.mukta(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: onSurface,
            side: const BorderSide(color: outline),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
            textStyle: GoogleFonts.mukta(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: CircleBorder(),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFFEEF2FF),
          labelStyle: GoogleFonts.mukta(fontSize: 11, fontWeight: FontWeight.w500),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          side: BorderSide.none,
        ),
        dividerTheme: const DividerThemeData(color: outline, thickness: 1, space: 0),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: surfaceCard,
          selectedItemColor: primary,
          unselectedItemColor: onSurfaceVariant,
          selectedLabelStyle: GoogleFonts.mukta(fontSize: 10, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.mukta(fontSize: 10),
          elevation: 8,
          type: BottomNavigationBarType.fixed,
        ),
      );

  static ThemeData get dark => light.copyWith(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: const ColorScheme.dark(
          primary: primary,
          onPrimary: Colors.white,
          surface: Color(0xFF161B22),
          onSurface: Color(0xFFE6EDF3),
          surfaceContainer: Color(0xFF1C2128),
          outline: Color(0xFF30363D),
        ),
      );
}
