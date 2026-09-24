# Getting started

A copy-pasteable, step-by-step guide to running this template locally
without an AI agent involved. If you'd rather have an AI agent do this for
you, see the README's "Quick start" and [`docs/ai-workflow.md`](ai-workflow.md)
instead.

## Prerequisites

- **Flutter, managed via [FVM](https://fvm.app/)** — this project pins its
  SDK version in `.fvmrc` and every command in this guide runs through
  `fvm`, never a bare `flutter`/`dart`. Install FVM first if you don't have
  it:
  ```
  dart pub global activate fvm
  ```
- **Xcode** (for iOS/macOS builds) and/or **Android Studio** (for Android
  builds), each with its own toolchain set up as `flutter doctor` expects.
  Run `flutter doctor` (or `fvm flutter doctor` once FVM is installed) to
  confirm both are configured correctly.

## 1. Install the pinned Flutter SDK

From the repo root:

```
fvm install
```

This reads `.fvmrc` and installs the exact Flutter version the project was
built against (`3.44.7` at the time of writing — always check `.fvmrc` for
the current pin). `.vscode/settings.json` also points at this exact
version (`dart.flutterSdkPath`); if you ever bump the pin with
`fvm use <version>`, that file is rewritten to match automatically — `.fvmrc`
stays the one place you edit the version by hand.

## 2. Rename the project

The template ships as `flutter_agentic_template` /
`com.alfredobs97.flutter_agentic_template` everywhere — the Dart package
name, Android `applicationId`, iOS bundle id, and the app's display name.
Rename these away from the template defaults before writing any feature
code. The Dart package rename is scriptable from the repo root:

```
fvm dart run tool/rename_project.dart --name your_app_name
```

Renaming the Android `applicationId`/display name
(`android/app/build.gradle.kts`), the iOS bundle id
(`ios/Runner.xcodeproj/project.pbxproj`, `ios/Flutter/flavor-*.xcconfig`)
and the app's display name in the ARB files (`appTitle` in
`packages/ui/lib/l10n/app_en.arb`/`app_es.arb`) are manual, grep-verified
steps — see
[`.agents/skills/bootstrap-project/SKILL.md`](../.agents/skills/bootstrap-project/SKILL.md)
for the full checklist (it's a plain step-by-step guide, no AI agent
required to follow it).

## 3. Fetch dependencies

```
fvm flutter pub get
```

Run this **at the repo root** — this is a Dart pub *workspace*
(`workspace:` in the root `pubspec.yaml`), so a single `pub get` at the root
resolves all four `pubspec.yaml` files together into one `pubspec.lock`.
Running it instead inside a single package directory (`packages/domain/`,
`packages/data/`, `packages/ui/`) also resolves correctly — each package's
own `pubspec.yaml` has `resolution: workspace` — which is a useful narrower
check after you've only touched that one package's dependencies, but the
root command already covers every package and is the normal entry point.

## 4. Run the app

Every `flutter run`/`flutter build` invocation needs **both** a
`--flavor <dev|prod>` flag and a matching `--dart-define=FLAVOR=<dev|prod>`
— they select the native build variant and the Dart-level environment
respectively, and must always agree (see `AGENTS.md` → "Flavors &
environments"). The easiest way to get this right every time is to use the
`.vscode/launch.json` configurations already checked into the repo:

- **Dev (Debug)** / **Dev (Profile)** / **Dev (Release)**
- **Prod (Debug)** / **Prod (Profile)** / **Prod (Release)**

Open the repo in VS Code, pick one from the Run and Debug panel, and launch.

If you'd rather run from the CLI directly, the equivalent for the Dev
Debug configuration is:

```
fvm flutter run --flavor dev --dart-define=FLAVOR=dev
```

Swap `dev` for `prod` (in both places, always together) to run the
production flavor instead.

## 5. Run the tests

Each package in the workspace is tested independently:

```
# Root app
fvm flutter test

# packages/domain — pure Dart, package:test only (no Flutter dependency)
cd packages/domain && fvm dart test && cd ../..

# packages/data
cd packages/data && fvm flutter test && cd ../..

# packages/ui
cd packages/ui && fvm flutter test && cd ../..
```

Or, to run everything (formatting, analysis, the architecture-boundary
check, the AI-config sync check, and every package's tests) in one pass:

```
fvm dart run tool/quality_gate.dart
```

This is the same command CI and this template's `quality-guardian` agent
run — if it's green locally, it'll be green there too.

## 6. Replace the placeholder app icon and splash screen

The template ships a placeholder at `assets/icon/app_icon.png`. Before your
first real build:

1. Replace `assets/icon/app_icon.png` with your own **1024x1024** artwork.
2. Regenerate the launcher icons:
   ```
   fvm dart run flutter_launcher_icons
   ```
3. Regenerate the native splash screen (the same artwork is reused for it —
   see the `flutter_native_splash` section of the root `pubspec.yaml` for
   the background colors):
   ```
   fvm dart run flutter_native_splash:create
   ```

Both generators are configured in the root `pubspec.yaml`; if you supply
your own native splash/icon assets by some other means instead, both
`dev_dependencies` (`flutter_launcher_icons`, `flutter_native_splash`) are
safe to remove.

## Next steps

- [`docs/architecture.md`](architecture.md) — the full architecture, and why
  it's shaped this way.
- [`docs/without-ai.md`](without-ai.md) — building features by hand, and
  using this template's skill docs as plain recipes without an AI agent.
- [`docs/ai-workflow.md`](ai-workflow.md) — using an AI agent to build on
  top of this template.
- [`docs/android-release-signing.md`](android-release-signing.md) and
  [`docs/ci-release-setup.md`](ci-release-setup.md) — optional, once you're
  ready to ship a signed build.
