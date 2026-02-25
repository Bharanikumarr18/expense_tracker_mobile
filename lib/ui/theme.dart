import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TrackerTheme {
  static const String defaultThemeName = 'Ocean';

  static const List<String> themeNames = ['Ocean', 'Slate', 'Emerald'];

  static bool isValidTheme(String name) => themeNames.contains(name);

  static ThemeData byName(String name) {
    switch (name) {
      case 'Slate':
        return _build(
          bg: const Color(0xFF111216),
          surface: const Color(0xFF171B22),
          accent: const Color(0xFFE879F9),
          secondary: const Color(0xFFBDB2FF),
        );
      case 'Emerald':
        return _build(
          bg: const Color(0xFF0E1511),
          surface: const Color(0xFF152019),
          accent: const Color(0xFF10B981),
          secondary: const Color(0xFF34D399),
        );
      case 'Ocean':
      default:
        return _build(
          bg: const Color(0xFF0B1220),
          surface: const Color(0xFF121B2E),
          accent: const Color(0xFF38BDF8),
          secondary: const Color(0xFF22D3EE),
        );
    }
  }

  static ThemeData _build({
    required Color bg,
    required Color surface,
    required Color accent,
    required Color secondary,
  }) {
    final base = ThemeData.dark(useMaterial3: true);

    final textTheme = GoogleFonts.manropeTextTheme(base.textTheme);

    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: accent,
        secondary: secondary,
        surface: surface,
      ),
      textTheme: textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      scaffoldBackgroundColor: bg,
      appBarTheme: AppBarTheme(backgroundColor: surface, elevation: 0),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        selectedIconTheme: IconThemeData(color: accent),
        selectedLabelTextStyle: TextStyle(color: accent),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
      ),
      dividerTheme: DividerThemeData(color: Colors.white.withOpacity(0.06)),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: const Color(0xFF0F1524),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: const Color(0xFF22293A),
        selectedColor: accent.withOpacity(0.25),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
    );
  }
}
