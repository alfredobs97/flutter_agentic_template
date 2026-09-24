---
name: flutter-fvm
description: States the rule that every flutter/dart command in this repo must be prefixed with fvm, maps common commands to their fvm equivalents, and covers first-time setup and monorepo/workspace behavior; load whenever you are about to run flutter run, build, test, analyze, format, or any pub command.
---

# Flutter version management (FVM)

## Prime directive

**Every `flutter` or `dart` command runs through `fvm`. No exceptions.**

```bash
# Wrong
flutter pub get
dart format .

# Right
fvm flutter pub get
fvm dart format -l 100 .
```

This repo pins its Flutter SDK in `.fvmrc`:

```json
{
  "flutter": "3.44.7"
}
```

A bare `flutter`/`dart` invocation uses whatever SDK happens to be first
on `PATH` — which may not exist, may be a different channel, or may be a
different version entirely from `3.44.7`. That mismatch is how you get
analyzer/lint differences, generated-code drift, and "works on my
machine" bugs that have nothing to do with the actual change being made.
`fvm flutter`/`fvm dart` always resolve to the exact pinned SDK, so the
whole team (and every agent) builds against the same toolchain as CI.

## Command mapping

| Bare command | Run instead |
|---|---|
| `flutter run` | `fvm flutter run` |
| `flutter pub get` | `fvm flutter pub get` |
| `flutter pub add <pkg>` | `fvm flutter pub add <pkg>` |
| `flutter test` | `fvm flutter test` |
| `flutter analyze` | `fvm flutter analyze --fatal-infos` |
| `flutter build ...` | `fvm flutter build ...` |
| `flutter gen-l10n` | `fvm flutter gen-l10n` |
| `dart format .` | `fvm dart format -l 100 .` |
| `dart fix --apply` | `fvm dart fix --apply` |
| `dart test` | `fvm dart test` |
| `dart run <script>` | `fvm dart run <script>` |

The `-l 100` on `dart format` matters — this repo formats at 100 columns,
not `dart format`'s 80-column default (see `analysis_options.yaml`'s note
on `lines_longer_than_80_chars`). Dropping the flag produces a diff that
reformats the whole file back to 80 columns.

See root `AGENTS.md` section 17 for the full command table, including
`fvm dart run tool/quality_gate.dart` and
`fvm dart run tool/check_architecture.dart`.

## First-time setup

1. Install FVM itself once per machine (not per project) — see
   [fvm.app](https://fvm.app) for your platform's install method. This
   skill assumes `fvm` is already on `PATH`; installing FVM itself is a
   one-time machine setup step, not something to redo per repo.
2. From the repo root, run:

   ```bash
   fvm install
   ```

   This reads `.fvmrc` and downloads Flutter `3.44.7` into FVM's cache if
   it isn't already there. It's safe to run even if the version is
   already installed — it's a no-op in that case.
3. Confirm the pin matches what you expect before doing anything else:

   ```bash
   cat .fvmrc
   fvm flutter --version
   ```

   The second command should report `3.44.7`. If it doesn't, `fvm use`
   was probably run against a different version at some point — re-run
   `fvm install` and check `.fvmrc` wasn't accidentally edited.

## Monorepo / pub workspace awareness

This repo is a **Dart pub workspace** (`pubspec.yaml`'s `workspace:` key
lists `packages/domain`, `packages/data`, `packages/ui`). That changes
where "get dependencies" should normally be run:

- **`fvm flutter pub get` at the repo root** resolves dependencies for
  the root app *and* all three member packages together, in one pass —
  this is the normal entry point. Run it here after pulling changes that
  touch any `pubspec.yaml` in the workspace, or after adding a dependency
  to any package.
- Running `fvm flutter pub get` **inside a package subdirectory**
  (`packages/domain/`, `packages/data/`, `packages/ui/`) also works —
  each package has `resolution: workspace` in its own `pubspec.yaml`,
  which tells pub to resolve it as part of the enclosing workspace rather
  than standalone. Useful when you only touched one package's
  dependencies and want a faster, narrower check, but it is not required
  — the root command already covers every package.
- `fvm flutter pub add <pkg>` run **inside a package directory** adds the
  dependency to that package's `pubspec.yaml` specifically (e.g. run it
  inside `packages/data/` to add a storage/network package there, not at
  the root — see root `AGENTS.md` section 2's dependency-direction
  table for which package should own a given dependency).

## Troubleshooting

- **`fvm: command not found`** — FVM itself isn't installed on this
  machine. Do not fall back to a bare `flutter`/`dart` command as a
  workaround; that silently defeats the whole point of pinning the SDK.
  Install FVM (see "First-time setup" above), then retry.
- **`fvm flutter ...` fails with "version not installed" or similar** —
  run `fvm install` from the repo root to fetch the version pinned in
  `.fvmrc`, then retry the original command.
- **A command behaves differently than expected / uses an unexpected SDK
  version** — run `fvm flutter --version` and compare against `.fvmrc`.
  If they disagree, re-run `fvm install`; if they agree and the problem
  persists, it isn't an FVM issue.
- **Never** "fix" an FVM error by dropping the `fvm` prefix and running
  the bare command instead — that's the one failure mode this whole
  skill exists to prevent.
