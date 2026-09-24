import 'package:flutter/material.dart';

/// Semantic color tokens. Widgets read these (or `context.theme.colorScheme`
/// for Material-mapped roles) — never a raw `Color(0xFF...)` literal. See
/// `.agents/skills/theming/SKILL.md` for how to swap this seed palette for
/// your brand's.
///
/// [seed] drives both [lightScheme] and [darkScheme] via
/// `ColorScheme.fromSeed`, so light/dark stay harmonious without hand-tuning
/// two full palettes. Replace it with your brand color and everything below
/// regenerates consistently.
abstract final class AppColors {
  static const Color seed = Color(0xFF6750A4);

  static const ColorScheme lightScheme = ColorScheme.light(primary: seed);
  static final ColorScheme darkScheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.dark,
  );

  /// Semantic roles with no Material 3 equivalent. Add here (not inline in a
  /// widget) whenever a color means something beyond `colorScheme`'s roles.
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFED6C02);
}
