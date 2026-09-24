import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// The app's light and dark [ThemeData], built once and reused —
/// see `lib/app.dart` at the app root, which wires both into
/// `MaterialApp.router(theme:, darkTheme:, themeMode: ThemeMode.system)`.
///
/// Add a component-specific sub-theme here (e.g. `cardTheme`,
/// `elevatedButtonTheme`) rather than styling that widget type inline at
/// every call site — see `.agents/skills/theming/SKILL.md`.
abstract final class AppTheme {
  static ThemeData get light => _themeFrom(AppColors.lightScheme);

  static ThemeData get dark => _themeFrom(AppColors.darkScheme);

  static ThemeData _themeFrom(ColorScheme colorScheme) {
    final base = ThemeData(colorScheme: colorScheme, useMaterial3: true);
    return base.copyWith(textTheme: AppTypography.textTheme(base.textTheme));
  }
}
