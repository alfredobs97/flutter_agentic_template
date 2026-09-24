---
name: theming
description: Covers how to add or change a design token — extending AppColors/AppSpacing/AppTypography, adding a component sub-theme to AppTheme instead of inline styling, swapping the seed brand color, adding a custom font, and when a widget belongs in common_widgets vs a feature's own widgets folder; triggers whenever the visual design system itself is being changed, not just consumed.
---

# Theming and design tokens

`packages/ui/lib/src/theme/` holds every design token: `AppColors`,
`AppSpacing`, `AppTypography`, `AppTheme`, and the `BuildContextX`
extension that exposes them to widgets. This skill is about *changing*
the design system itself — for consuming existing tokens in a screen, see
`.agents/skills/ui-screen/SKILL.md` section 3.

## 1. Extending `AppColors`

Add a new semantic color only when it means something Material's
`ColorScheme` roles don't already cover (`primary`, `secondary`,
`error`, `surface`, ...). Check `context.theme.colorScheme` first.

```dart
abstract final class AppColors {
  static const Color seed = Color(0xFF6750A4);

  static const ColorScheme lightScheme = ColorScheme.light(primary: seed);
  static final ColorScheme darkScheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.dark,
  );

  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFED6C02);
  // New semantic role — added only because neither `error` nor any other
  // ColorScheme role fits "a value the user should double-check".
  static const Color caution = Color(0xFFF9A825);
}
```

Never reference `AppColors.success`/`warning`/etc. directly for something
that already has a `colorScheme` equivalent — e.g. don't add a `danger`
alias for `colorScheme.error`.

## 2. Extending `AppSpacing`

Add a new `spaceN` value only if it doesn't already sit on the 4pt scale,
and prefer adding a new **semantic alias** for a recurring layout need
over reaching for a raw `spaceN` constant at every call site:

```dart
abstract final class AppSpacing {
  static const double space1 = 4;
  static const double space2 = 8;
  // ...

  /// Gap between a list item's leading icon and its label — recurring
  /// enough across features to deserve its own name instead of every
  /// call site picking space2 by convention.
  static const double iconLabelGap = space2;
}
```

## 3. Extending `AppTypography`

`AppTypography.textTheme(base)` takes Flutter's default `TextTheme` and
returns the app's. The template ships it as a pass-through (no custom
font, kept dependency-light):

```dart
abstract final class AppTypography {
  static TextTheme textTheme(TextTheme base) => base;
}
```

Add an override here — not a one-off `TextStyle` at a call site — when a
specific text role needs a consistent treatment app-wide (e.g. every
`titleLarge` should be slightly heavier):

```dart
abstract final class AppTypography {
  static TextTheme textTheme(TextTheme base) => base.copyWith(
    titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w600),
  );
}
```

Colors stay out of `AppTypography` deliberately — `ThemeData` applies
`colorScheme.onSurface` (and friends) to text automatically, so a widget
reads `context.theme.textTheme.titleMedium` without a color baked in.
Don't add a `color:` to a style here; that would fight the automatic
on-color mapping and break dark mode.

## 4. Adding a component sub-theme instead of inline styling

If you find yourself passing the same `style:`/`shape:`/`padding:` to
every instance of a widget type across the app, that belongs in
`AppTheme` as a component sub-theme, not repeated at each call site:

```dart
// Wrong — repeated at every ElevatedButton call site across the app
ElevatedButton(
  style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
  )),
  onPressed: onPressed,
  child: child,
);

// Right — set once in AppTheme, every ElevatedButton in the app picks it up
abstract final class AppTheme {
  static ThemeData get light => _themeFrom(AppColors.lightScheme);
  static ThemeData get dark => _themeFrom(AppColors.darkScheme);

  static ThemeData _themeFrom(ColorScheme colorScheme) {
    final base = ThemeData(colorScheme: colorScheme, useMaterial3: true);
    return base.copyWith(
      textTheme: AppTypography.textTheme(base.textTheme),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
    );
  }
}
```

A widget then just writes `ElevatedButton(onPressed: ..., child: ...)` or
`Card(child: ...)` with zero styling arguments, and every instance in the
app stays visually consistent by construction — a design change becomes a
one-file edit instead of a find-and-replace across every screen.

## 5. Swapping the brand seed color

`AppColors.seed` drives both `lightScheme` and `darkScheme` via
`ColorScheme.fromSeed` (light mode is expressed via the simpler
`ColorScheme.light(primary: seed)` constructor here, but both ultimately
derive from the same seed value). Replacing the neutral template seed
with a real brand color is a one-line change that regenerates a
harmonious light *and* dark palette without hand-tuning either:

```dart
abstract final class AppColors {
  // Was: static const Color seed = Color(0xFF6750A4);
  static const Color seed = Color(0xFF0057B8); // brand primary
  // lightScheme/darkScheme below are unchanged — both re-derive from seed.
};
```

`AppTheme.light`/`AppTheme.dark` and every widget that reads
`context.theme.colorScheme.primary` update automatically; there's no
second place to edit. Verify the swap with the existing theme test's
expectations in mind (`packages/ui/test/theme/app_theme_test.dart` checks
`AppTheme.light.colorScheme.primary == AppColors.lightScheme.primary`)
and check contrast for any hardcoded on-primary text.

## 6. Adding a custom font

The template ships no custom typeface by design. To add one:

1. Add the font dependency — either `google_fonts` (`fvm flutter pub add
   google_fonts` from `packages/ui/`) for a hosted font, or a font asset
   declared under `flutter: fonts:` in `packages/ui/pubspec.yaml` for a
   licensed/custom file.
2. Replace `AppTypography.textTheme`'s pass-through with the font
   applied to the base `TextTheme`:

   ```dart
   // With google_fonts:
   abstract final class AppTypography {
     static TextTheme textTheme(TextTheme base) => GoogleFonts.interTextTheme(base);
   }
   ```

   ```dart
   // With a bundled font asset (pubspec.yaml `flutter: fonts:` entry
   // named "Inter"):
   abstract final class AppTypography {
     static TextTheme textTheme(TextTheme base) => base.apply(fontFamily: 'Inter');
   }
   ```
3. `AppTheme._themeFrom` already calls `AppTypography.textTheme(base.textTheme)`
   — no further wiring needed; both light and dark themes pick it up.

## 7. `common_widgets/` vs a feature's own `widgets/` folder

A new widget starts in its feature's own
`features/<feature>/presentation/widgets/` folder. It is promoted to
`packages/ui/lib/src/common_widgets/` only once a **second**, different
feature genuinely needs the same widget — not pre-emptively, and not just
because it "feels generic" (YAGNI, per `packages/ui/AGENTS.md` and the
`common_widgets.dart` barrel's doc comment). Before writing a new widget
at all, check whether a plain Material widget already covers the need.

```dart
// First use: features/tasks/presentation/widgets/task_card.dart
// A second feature later needs the identical card (e.g. features/archive/):
// now — and only now — move it to:
// packages/ui/lib/src/common_widgets/task_card.dart
// and export it from common_widgets.dart.
```

## Common mistakes

- Adding a raw `Color(0xFF...)` or magic-number spacing value instead of
  a token, even "just this once".
- Styling a widget type inline at every call site instead of adding an
  `AppTheme` sub-theme.
- Baking a color into an `AppTypography` text style, breaking automatic
  dark-mode on-color mapping.
- Promoting a widget to `common_widgets/` on its first use, "just in
  case" a second feature needs it later.
- Forgetting that `AppColors.lightScheme` and `darkScheme` are built two
  different ways (`ColorScheme.light` vs `ColorScheme.fromSeed`) — both
  must be checked after any seed-related change.

## Checklist

- [ ] New color/spacing/typography value added to the matching token
      class, not inlined at the call site.
- [ ] A widget-type-wide style goes into `AppTheme` as a sub-theme, not
      repeated per call site.
- [ ] Any seed-color change verified against both `AppColors.lightScheme`
      and `darkScheme`.
- [ ] A new widget stays in its feature's `widgets/` folder until a
      second feature needs it; only then does it move to
      `common_widgets/` (with the barrel updated).
- [ ] `packages/ui/test/theme/app_theme_test.dart`-style coverage still
      passes after a token change.
