import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class IronLogTheme {
  static const _seed = Color(0xFFFFB300);

  // Static finals — constructed once at startup, not on every build().
  static final ThemeData light = _light();
  static final ThemeData dark = _dark();

  static ThemeData _light() {
    final cs = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
    );
    return ThemeData(
      colorScheme: cs,
      useMaterial3: true,
      // Typography.material2021().black is the canonical M3 light text baseline —
      // avoids allocating a full ThemeData just to get the TextTheme.
      textTheme: GoogleFonts.dmSansTextTheme(Typography.material2021().black),
    );
  }

  static ThemeData _dark() {
    final base = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    );
    // Force the true-black surface stack so the UI reads as powerlifting-dark,
    // not the lighter grey Material 3 defaults.
    final cs = base.copyWith(
      surface: const Color(0xFF121212),
      surfaceContainerLowest: const Color(0xFF0A0A0A),
      surfaceContainerLow: const Color(0xFF181818),
      surfaceContainer: const Color(0xFF1E1E1E),
      surfaceContainerHigh: const Color(0xFF242424),
      surfaceContainerHighest: const Color(0xFF2C2C2C),
    );
    return ThemeData(
      colorScheme: cs,
      useMaterial3: true,
      // Typography.material2021().white is the canonical M3 dark text baseline.
      textTheme: GoogleFonts.dmSansTextTheme(Typography.material2021().white),
    );
  }
}
