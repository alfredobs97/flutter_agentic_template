import 'package:flutter/material.dart';

/// Builds the app's [TextTheme] from Flutter's default type ramp.
///
/// The template deliberately ships no custom font (no `google_fonts`
/// dependency, to stay dependency-light) — see
/// `.agents/skills/theming/SKILL.md` for how to swap in a custom typeface:
/// add the font package/asset, then replace `ThemeData.textTheme` in
/// `app_theme.dart` with `GoogleFonts.xTextTheme(base)` or a `fontFamily`
/// override.
///
/// Colors are intentionally NOT baked into these styles — [ThemeData]
/// applies `colorScheme.onSurface` (and friends) to text automatically, so
/// widgets should read `context.theme.textTheme.titleMedium`, not a color
/// hardcoded here.
abstract final class AppTypography {
  static TextTheme textTheme(TextTheme base) => base;
}
