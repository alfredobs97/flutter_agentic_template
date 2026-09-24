import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// Shortcuts for the values a widget's build method reaches for constantly.
///
/// See AGENTS.md → "Widget build helpers & BuildContext injection": a
/// private `_build*`/helper method should, by default, take at most a
/// single `BuildContext context` parameter and derive `theme`/`l10n` from
/// it via this extension — never thread `ThemeData`/`AppLocalizations` as
/// explicit parameters. If another value is always derivable from
/// `BuildContext` (a commonly-read provider, for instance), add a getter
/// here rather than calling `context.read<X>()` ad-hoc in many places.
extension BuildContextX on BuildContext {
  ThemeData get theme => Theme.of(this);

  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
