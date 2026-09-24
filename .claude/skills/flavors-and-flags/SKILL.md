---
name: flavors-and-flags
description: Explains how the dev/prod flavor system works end to end across AppEnvironment, Android product flavors, iOS xcconfigs and .vscode/launch.json, and how to add a new per-flavor FeatureFlag; load before adding a feature flag, changing a flavor-specific default, or touching flavor/build-flag wiring.
---

# Flavors and feature flags

## 1. How the flavor system works end to end

There are exactly two build flavors: `dev` and `prod`. Three things must
always agree, and the template wires them so that using
`.vscode/launch.json` is the only way you need to think about this:

1. **`--dart-define=FLAVOR=<dev|prod>`** — read once by
   `lib/app_environment.dart`:

   ```dart
   enum AppFlavor { dev, prod }

   abstract final class AppEnvironment {
     static const String _name = String.fromEnvironment('FLAVOR', defaultValue: 'dev');

     static AppFlavor get flavor => _name == 'prod' ? AppFlavor.prod : AppFlavor.dev;
   }
   ```

   This is a compile-time constant (`String.fromEnvironment`), so
   `AppEnvironment.flavor` is available anywhere in Dart code without
   plumbing it through constructors — `lib/bootstrap.dart` reads it once
   to pick feature-flag defaults (see section 2).

2. **`--flavor <dev|prod>`** — the *native* flag. On Android it selects
   the Gradle `productFlavor` declared in `android/app/build.gradle.kts`:

   ```kotlin
   flavorDimensions += "env"
   productFlavors {
       create("dev") {
           dimension = "env"
           applicationIdSuffix = ".dev"
           versionNameSuffix = "-dev"
           resValue(type = "string", name = "app_name", value = "Flutter Agentic Template Dev")
       }
       create("prod") {
           dimension = "env"
           resValue(type = "string", name = "app_name", value = "Flutter Agentic Template")
       }
   }
   ```

   On iOS it selects the Xcode scheme/configuration, which includes
   `ios/Flutter/flavor-dev.xcconfig` or `flavor-prod.xcconfig` —
   per-flavor overrides for the bundle id suffix and display name:

   ```
   // flavor-dev.xcconfig
   APP_BUNDLE_ID_SUFFIX=.dev
   APP_DISPLAY_NAME=Flutter Agentic Template Dev
   ```

3. **Both flags are required on every `flutter run`/`flutter build`, and
   must always agree.** A `--flavor prod` build carrying
   `--dart-define=FLAVOR=dev` installs as the production app (prod
   bundle id, prod signing, prod app name) while `AppEnvironment.flavor`
   — and therefore every feature-flag default and the `(Dev)` title
   suffix — reports itself as `dev`. This is a real, silent-failure-mode
   footgun, which is why the template does not want you typing these
   flags by hand.

Use `.vscode/launch.json`'s six configurations instead — they pair every
flavor with every run mode:

| Configuration | `--flavor` | `--dart-define=FLAVOR` | Mode |
|---|---|---|---|
| Dev (Debug) | `dev` | `dev` | debug |
| Dev (Profile) | `dev` | `dev` | profile |
| Dev (Release) | `dev` | `dev` | release |
| Prod (Debug) | `prod` | `prod` | debug |
| Prod (Profile) | `prod` | `prod` | profile |
| Prod (Release) | `prod` | `prod` | release |

If you must run from the terminal instead of the VS Code/editor launch
UI, copy the pair of flags from the matching configuration verbatim, e.g.:

```bash
fvm flutter run --flavor dev --dart-define=FLAVOR=dev
```

Never type only one of the two flags, and never let a script default one
of them independently of the other.

## 2. Adding a new `FeatureFlag`

`FeatureFlag` (`packages/domain/lib/src/entities/feature_flag.dart`) is a
small, closed enum — one value per toggle:

```dart
enum FeatureFlag {
  exampleFeature,
}
```

To add a flag, e.g. a `taskReminders` feature still being finished:

1. **Add the enum value** in `packages/domain/lib/src/entities/feature_flag.dart`:

   ```dart
   enum FeatureFlag {
     exampleFeature,
     taskReminders,
   }
   ```

2. **Set its per-flavor default** in `lib/feature_flag_defaults.dart`
   (repo root). This is the single place flavor and flag intersect — it's
   a pure `Map` literal per `AppFlavor`, called once from
   `bootstrap()`:

   ```dart
   Map<FeatureFlag, bool> featureFlagDefaultsFor(AppFlavor flavor) => switch (flavor) {
     AppFlavor.dev => {
       FeatureFlag.exampleFeature: true,
       FeatureFlag.taskReminders: true, // on in dev while the feature is finished
     },
     AppFlavor.prod => {
       FeatureFlag.exampleFeature: false,
       FeatureFlag.taskReminders: false, // hidden from real users until it's done
     },
   };
   ```

   A flag doesn't have to differ per flavor — plenty of flags are simply
   "on everywhere" or "off everywhere" and only exist so a Cubit can gate
   on them without a code change later:

   ```dart
   Map<FeatureFlag, bool> featureFlagDefaultsFor(AppFlavor flavor) => switch (flavor) {
     AppFlavor.dev => {
       FeatureFlag.exampleFeature: true,
       FeatureFlag.taskReminders: true,
       FeatureFlag.darkModeToggle: true, // same value in both flavors
     },
     AppFlavor.prod => {
       FeatureFlag.exampleFeature: false,
       FeatureFlag.taskReminders: false,
       FeatureFlag.darkModeToggle: true, // same value in both flavors
     },
   };
   ```

3. **Read it in UI** via the app-wide `FeatureFlagCubit` (provided once
   in `lib/app.dart`, above `MaterialApp.router`):

   ```dart
   Widget _buildReminderBanner(BuildContext context) {
     final remindersEnabled = context.watch<FeatureFlagCubit>().state.isEnabled(
       FeatureFlag.taskReminders,
     );
     return remindersEnabled ? const ReminderBanner() : const SizedBox.shrink();
   }
   ```

   `context.watch<FeatureFlagCubit>()` rebuilds the widget if the
   underlying state ever changes; use `context.read<FeatureFlagCubit>()`
   instead inside a one-off callback (e.g. inside a Cubit method or an
   `onPressed`) where a rebuild isn't needed.

A flag not present in the underlying map defaults to `false` (see
`FeatureFlags.isEnabled` in `feature_flag.dart`), so adding a new
`FeatureFlag` value is never a breaking change for code that reads an
older flag.

## 3. What this system is *not*

`FeatureFlag`/`FeatureFlagRepository` is a small, closed, build-time
toggle — values are fixed at process start from
`featureFlagDefaultsFor(AppEnvironment.flavor)` and never change again
during that run. **This is not a remote-config or A/B-testing system**,
by design: no server call, no per-user targeting, no runtime rollout
percentage, no over-the-air update without a new build.

If you need any of that, the extension point is
`FeatureFlagRepository`'s backing (`packages/domain/lib/src/repositories/feature_flag_repository.dart`)
— today it's constructed directly from a `FeatureFlags` map built at
startup:

```dart
final featureFlagRepository = FeatureFlagRepository(
  FeatureFlags(featureFlagDefaultsFor(AppEnvironment.flavor)),
);
```

Replacing this with a `data`-layer remote-config provider (a new
`data_provider` interface in `domain`, implemented against your chosen
backend in `data`, injected the same way every other repository is in
`lib/bootstrap.dart`) is the correct place to add that capability. The
`FeatureFlag` enum and `FeatureFlagCubit`/`FeatureFlagState` in
`package:ui` would not need to change — this skill does not implement
that provider; see `.agents/skills/choose-data-stack/SKILL.md` and
`.agents/skills/data-provider/SKILL.md` when you actually need it.
