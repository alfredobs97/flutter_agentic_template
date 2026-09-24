---
name: bootstrap-project
description: Renames this template's Dart package, Android application id, iOS bundle id, app display name and app icon when starting a brand-new app from the clone; run this once, first, before any other skill or feature work.
---
# Bootstrap a new app from the template

This template ships as `flutter_agentic_template` / `com.alfredobs97.flutter_agentic_template`
everywhere — the root Dart package name, the Android `applicationId`, the iOS
`PRODUCT_BUNDLE_IDENTIFIER`, and the display name shown on the home screen and
in the OS task switcher. Run this skill exactly once, immediately after
cloning the template and before writing any feature code (AGENTS.md
introduction and section 19 both point here first).

Work through the steps in order. Steps 1–2 are automatable; steps 3–5 touch
native project files that Xcode/Gradle tooling can silently corrupt if
scripted blindly, so do them by hand, file by file, and verify with `grep`
after each edit.

## 1. Rename the Dart package

The root `pubspec.yaml`'s `name:` field and every `package:flutter_agentic_template`
import across `lib/` and `test/` must change together, or the workspace fails
to resolve.

Run the bundled codemod from the repo root:

```bash
fvm dart run tool/rename_project.dart --name your_app_name
```

This rewrites:
- `pubspec.yaml`'s top-level `name:` field.
- Every `import 'package:flutter_agentic_template/...'` in `lib/` and `test/`
  (see `test/app_test.dart`, `test/widget_test.dart`,
  `test/app_environment_test.dart`, `test/feature_flag_defaults_test.dart` for
  the current occurrences) to `import 'package:your_app_name/...'`.

Pass a valid Dart package name: lowercase `snake_case`, no leading digit. The
three workspace packages (`domain`, `data`, `ui`) are intentionally **not**
renamed by this tool — their names are generic on purpose and never appear in
a store listing.

After running it, confirm nothing was missed:

```bash
grep -rn "flutter_agentic_template" --include="*.dart" lib/ test/ packages/
```

The only expected remaining hits are inside `packages/*` doc comments that
reference this skill or `AGENTS.md` by description, not by import — read each
hit before assuming it's stale.

## 2. Verify the workspace still resolves

```bash
fvm flutter pub get
```

Run this at the repo root (it's a pub workspace — see AGENTS.md section 17).
A renamed package with a stale import anywhere still fails this step; fix any
`Target of URI doesn't exist` error it reports before moving on.

## 3. Change the Android applicationId and display name

Edit `android/app/build.gradle.kts` by hand:

```kotlin
android {
    namespace = "com.yourcompany.your_app"   // was com.alfredobs97.flutter_agentic_template
    ...
    defaultConfig {
        applicationId = "com.yourcompany.your_app"   // was com.alfredobs97.flutter_agentic_template
        ...
    }
    ...
    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            resValue(type = "string", name = "app_name", value = "Your App Dev")
        }
        create("prod") {
            dimension = "env"
            resValue(type = "string", name = "app_name", value = "Your App")
        }
    }
}
```

The `dev`/`prod` flavor structure (base id + `.dev` suffix for the dev build)
already matches the two-flavor setup described in AGENTS.md section 14 —
change only the `namespace`, `applicationId` and the two `resValue app_name`
strings, not the flavor structure itself.

Verify: `grep -n "alfredobs97" android/app/build.gradle.kts` returns nothing.

## 4. Change the iOS bundle id and display name

The iOS bundle id is **not** centralized in one file. The base id is baked
into `ios/Runner.xcodeproj/project.pbxproj` as
`PRODUCT_BUNDLE_IDENTIFIER = "com.alfredobs97.flutterAgenticTemplate$(APP_BUNDLE_ID_SUFFIX)"`
(note the camelCase form — Xcode identifiers don't use underscores). Find
every occurrence:

```bash
grep -n "flutterAgenticTemplate" ios/Runner.xcodeproj/project.pbxproj
```

This currently matches six `XCBuildConfiguration` blocks: **Debug**,
**Debug-dev**, **Debug-prod**, **Release**, **Release-dev**, **Release-prod**
(and the corresponding **Profile-dev**/**Profile-prod** blocks, plus the
`RunnerTests` target's own three). Replace `flutterAgenticTemplate` with your
app's identifier segment (camelCase, e.g. `yourApp`) in every match — a
partial replace leaves some build configurations pointing at the old bundle
id, which only surfaces later as a confusing code-signing mismatch.

Then edit the two flavor xcconfig files, which supply the suffix and the
display name for the `-dev`/`-prod` build configurations referenced above:

`ios/Flutter/flavor-dev.xcconfig`:
```
APP_BUNDLE_ID_SUFFIX=.dev
APP_DISPLAY_NAME=Your App Dev
```

`ios/Flutter/flavor-prod.xcconfig`:
```
APP_BUNDLE_ID_SUFFIX=
APP_DISPLAY_NAME=Your App
```

Verify: `grep -rn "flutterAgenticTemplate\|Flutter Agentic Template" ios/` returns nothing outside of comments you intentionally left.

## 5. Change the app display name in localized strings

The ARB source files also carry the display name as the `appTitle` key,
consumed via `context.l10n.appTitle` in `onGenerateTitle` (`lib/app.dart`) —
see AGENTS.md section 11 for the localization workflow.

`packages/ui/lib/l10n/app_en.arb`:
```json
{
  "appTitle": "Your App",
  "@appTitle": {
    "description": "The app's display name, used as the MaterialApp title and in the OS task switcher."
  }
}
```

`packages/ui/lib/l10n/app_es.arb`:
```json
{
  "appTitle": "Tu App"
}
```

Then regenerate from `packages/ui/`:

```bash
cd packages/ui && fvm flutter gen-l10n
```

## 6. Replace the placeholder app icon

Drop your own 1024×1024 artwork at `assets/icon/app_icon.png` (overwriting
the placeholder), then regenerate native icons and the splash screen from the
repo root:

```bash
fvm dart run flutter_launcher_icons
fvm dart run flutter_native_splash:create
```

Both generators are already configured in the root `pubspec.yaml`
(`flutter_launcher_icons:` / `flutter_native_splash:` sections) — you only
need to supply the artwork, not touch the config, unless you also want to
change the splash background color (`color`/`color_dark`, currently
`#0E0E10`).

## 7. Final repo-wide sanity check

Even though the previous steps cover every known occurrence, do one last
sweep before calling the bootstrap done — a fork or a future template update
could have added a new reference:

```bash
grep -rn "alfredobs97\|flutter_agentic_template\|flutterAgenticTemplate\|Flutter Agentic Template" \
  --include="*.dart" --include="*.yaml" --include="*.yml" --include="*.arb" \
  --include="*.xcconfig" --include="*.kts" --include="*.plist" . \
  | grep -v "/build/" | grep -v "ios/Flutter/Generated.xcconfig"
```

`ios/Flutter/Generated.xcconfig` is excluded because Flutter regenerates it
on every build from `ios/Flutter/flavor-*.xcconfig` and the Xcode project —
never hand-edit it.

`ai/agents/*.yaml` and `ai/mcp.yaml` do not currently reference
`com.alfredobs97` or the template's package name, so no edit is expected
there — the grep above is the check that stays true, not a step that should
find something.

The git remote and turning this clone into your own GitHub repository (or
detaching it from the template relationship) are manual steps outside this
skill's scope — this skill only covers in-repo identifiers.

## 8. Confirm the quality gate still passes

```bash
fvm flutter pub get
fvm dart run tool/quality_gate.dart
```

This runs format, analyze, the architecture-boundary check, the AI-config
sync check and the full test suite (AGENTS.md section 17) — a passing run
here is the signal that every rename above was applied consistently and
nothing is left half-renamed.

## Checklist

- [ ] `pubspec.yaml` `name:` and every `package:` import in `lib/`/`test/`
      updated (via `tool/rename_project.dart`).
- [ ] `fvm flutter pub get` resolves cleanly from the repo root.
- [ ] Android `namespace`, `applicationId`, and both `resValue app_name`
      strings updated in `android/app/build.gradle.kts`.
- [ ] Every `PRODUCT_BUNDLE_IDENTIFIER` occurrence in
      `ios/Runner.xcodeproj/project.pbxproj` updated (six-plus matches,
      including the `RunnerTests` target).
- [ ] `APP_DISPLAY_NAME` updated in both `ios/Flutter/flavor-dev.xcconfig`
      and `ios/Flutter/flavor-prod.xcconfig`.
- [ ] `appTitle` updated in `app_en.arb` and `app_es.arb`, `fvm flutter
      gen-l10n` re-run.
- [ ] `assets/icon/app_icon.png` replaced, `flutter_launcher_icons` and
      `flutter_native_splash:create` re-run.
- [ ] Final repo-wide grep for `alfredobs97`/`flutter_agentic_template`
      returns nothing unexpected.
- [ ] `fvm dart run tool/quality_gate.dart` exits 0.

## Common mistakes

- Renaming the Dart package but leaving native ids untouched — the app
  builds and runs, but ships under the template's own bundle id, which will
  collide with the template author's app on a shared device or app store.
- Editing only the `Debug`/`Release` `PRODUCT_BUNDLE_IDENTIFIER` entries in
  `project.pbxproj` and missing the `-dev`/`-prod` flavor variants (or the
  `RunnerTests` target) — always grep for every match, don't eyeball the
  file.
- Hand-editing `ios/Flutter/Generated.xcconfig` — it is regenerated by
  Flutter tooling and any manual edit is silently discarded.
- Forgetting `fvm flutter gen-l10n` after editing the ARB files — the old
  `appTitle` string stays baked into the generated `AppLocalizations` class
  until regenerated.
- Running `tool/rename_project.dart` from inside a package directory instead
  of the repo root.
