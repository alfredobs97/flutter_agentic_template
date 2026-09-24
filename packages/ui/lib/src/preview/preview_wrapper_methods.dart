import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/theme.dart';

/// Wraps [child] with the app's theme and localization delegates, so a
/// widget can be previewed (in a `@Preview` annotation, DevTools Widget
/// Preview, or a standalone widget test) without booting the full
/// `MaterialApp.router` + `RepositoryProvider` tree from `lib/app.dart`.
///
/// ```dart
/// @Preview(name: 'Home screen')
/// Widget homeScreenPreview() => appPreviewWrapper(const HomeScreen());
/// ```
Widget appPreviewWrapper(Widget child) => MaterialApp(
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);
