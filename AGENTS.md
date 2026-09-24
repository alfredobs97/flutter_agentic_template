# Flutter Agentic Template — Architectural Rules for Agents

This is a Flutter template that follows a strict **Clean Architecture**
implementation using **Dart pub workspaces** to enforce layer boundaries
through a monorepo structure. Despite the "for Agents" name — kept because
several AI coding tools (Claude Code, OpenAI Codex, Google Antigravity,
OpenCode, Pi) look specifically for a file with this name — this document
is the project's conventions guide for every contributor, human or AI: the
whole point is to let anyone (or anything) writing code here produce code
indistinguishable from a senior engineer's. Read it before writing
anything, and follow it exactly even when a shortcut would "work". See
[`docs/without-ai.md`](docs/without-ai.md) if you're building by hand.

If you are starting a brand-new app from this template, run the
`bootstrap-project` skill first (renames the package, bundle IDs and app
name). If you haven't picked a persistence/network stack yet, run
`choose-data-stack` before writing your first data provider.

## 1. Monorepo structure

The project is divided into a root Composition Root and three local packages
inside `packages/`:

- **`packages/domain/`** — the core business logic layer. Pure Dart.
- **`packages/data/`** — the external integrations layer.
- **`packages/ui/`** — the presentation and state management layer.

Each package has its own `AGENTS.md` with layer-specific detail; this file
holds the rules that span all of them. **Before editing any file under
`packages/<pkg>/`, read `packages/<pkg>/AGENTS.md` first.** Some harnesses
only load an `AGENTS.md` by walking upward from the file being edited (so a
package's own file is picked up automatically); others load only the one
in the directory the session started from and never discover a nested one
on their own — do not assume yours is the former.

## 2. Dependency rule

Dependencies point ONLY inward, toward `domain`:

| Package | May import | Must NOT import |
|---|---|---|
| `domain` | `equatable`, `meta` | `flutter`, `data`, any storage/network package |
| `data` | `domain`, storage/network packages | `flutter`, `ui` |
| `ui` | `flutter`, `domain` | `data` (never — see below) |
| root (`lib/`) | `domain`, `data`, `ui` | — (this is the only place `data` and `ui` are both imported) |

`data` implements the `data_provider` interfaces defined in `domain` and
contains every external dependency (Drift, Dio, Firebase, ...). We do **not**
use the repository-interface pattern or use cases: repositories are concrete
classes that live entirely in `domain` and depend on `data_provider`
interfaces via constructor injection.

The root package (`flutter_agentic_template`) is the **composition root**
(`lib/bootstrap.dart`). This is the only place where `data` is imported to
build repositories and inject them into `ui` via `RepositoryProvider`.

This boundary is enforced two ways: by never adding `data` as a dependency
of `ui`'s `pubspec.yaml` (a missing dependency is a hard pub-get error, not
just a lint), and by `dart run tool/check_architecture.dart` — part of
`tool/quality_gate.dart` — which also catches `flutter`/`dart:io` imports in
`domain` and imports that reach into another package's `src/`.

## 3. State management & dependency injection

- **State management**: `flutter_bloc` (Bloc or Cubit — see
  `.agents/skills/state-management/SKILL.md` for which to pick).
- **Dependency injection**: manual constructor injection, wired once in
  `lib/bootstrap.dart` and exposed via `RepositoryProvider`/`MultiRepositoryProvider`
  at the root of the widget tree (`lib/app.dart`). Do **not** use `get_it`
  or any other service locator unless the user explicitly asks for one.

## 4. Language & documentation

All code, comments, documentation, variables and function names are written
in **English**. Do not add a comment that restates what the code already
says; add one only where the *why*, not the *what*, needs explaining.

## 5. Flutter version management (FVM)

The project pins its Flutter SDK with **FVM** (`.fvmrc`). Always run
`fvm flutter ...` / `fvm dart ...`, never a bare `flutter`/`dart` — see the
`flutter-fvm` skill, loaded automatically whenever you run a Flutter/Dart
command.

## 6. Testing requirements

Every new entity, data provider, repository, Cubit/BLoC, widget or route
gets a test in the same change that introduces it — see
`.agents/skills/testing/SKILL.md` for the pattern per layer and
`test/helpers/` / `packages/*/test/helpers/` for shared fakes and pumpers.
A change is not done until `dart run tool/quality_gate.dart` passes.

## 7. Data layer workflow

This template ships **no persistence or network package** — `packages/data`
has zero storage/network dependencies until you run
`.agents/skills/choose-data-stack/SKILL.md`. Once a stack is chosen, adding a
feature follows this sequence (see `.agents/skills/new-feature/SKILL.md` for
the full generator):

1. **Domain layer** (`packages/domain/`):
   - **Entity** in `lib/src/entities/`: pure Dart, `Equatable`, hand-written
     `copyWith` (sentinel pattern for explicitly-clearable nullable fields —
     see `entities.dart`'s doc comment).
   - **Variant inheritance**: an entity tied to another entity is a subclass
     with a non-nullable reference (`AssignedTask extends Task`), not a
     nullable field on the base class, so callers use
     `if (task is AssignedTask)` instead of null checks.
   - **List ordering**: if a field's list order is meaningful, expose a
     `sortedX` getter rather than assuming the backing field is sorted.
   - **Data-provider interface** in `lib/src/data_providers/`: an
     `abstract interface class` in terms of entities only — no SQL/HTTP.
   - **Concrete repository** in `lib/src/repositories/`: takes the
     interface via constructor injection; holds the orchestration a use
     case would normally hold.
   - **Export** all three from `lib/domain.dart`.

2. **Data layer** (`packages/data/`):
   - Implement the interface in `lib/src/data_providers/`, wrapping your
     chosen package.
   - Wrap every method body in `guard`/`guardStream`
     (`lib/src/guards/failure_guard.dart`) with a `FailureMapper` specific
     to that package's exceptions — see section 11 below.
   - If using a database with foreign keys, index every FK column and every
     column used in a `WHERE`/`ORDER BY`.
   - If using Drift and a `watch()` query needs data from a joined table,
     pull it in via a `join`/`leftOuterJoin` on the same `.watch()`, not a
     separate `.get()` inside `asyncMap` — otherwise writes to the related
     table silently fail to re-emit.
   - **Export** from `lib/data.dart`.

3. **Composition root** (`lib/bootstrap.dart`):
   - Instantiate the data provider, then the repository, then add it as a
     named parameter to `App` (`lib/app.dart`) and a matching
     `RepositoryProvider.value`.

4. **UI** (`packages/ui/`): see sections 8–10 below.
   - **`ui` MUST NEVER import `packages/data` directly.**

## 8. UI structure & the Screen/View split

Each feature lives under `packages/ui/lib/src/features/<feature>/` with
`bloc/`, `presentation/` (screens, plus a `widgets/` subfolder for
screen-local widgets), and optionally `models/` for UI-only value types
(form drafts, navigation arguments). `home/` is a worked example of the
`presentation/` half of this layout — see
`.agents/skills/new-feature/SKILL.md` and `.agents/skills/ui-screen/SKILL.md`
for the full pattern including the Cubit half.

A screen that owns a Cubit is split into a public `XScreen` (creates the
Cubit via `BlocProvider(create: ...)`, reading its dependencies with
`context.read<Repo>()`) and a private `_XView` (consumes it via
`BlocBuilder`). A screen that only reads an app-wide Cubit (provided in
`lib/app.dart`) skips the `BlocProvider` step — see `home_screen.dart`.

## 9. Error handling

`packages/domain/lib/src/failures/domain_failure.dart` defines a sealed
`DomainFailure` hierarchy. Data providers in `packages/data` **must**
translate infrastructure exceptions (Drift, Dio, PlatformException, ...)
into a `DomainFailure` at the provider boundary — via `guard`/`guardStream`
(`packages/data/lib/src/guards/failure_guard.dart`) with a `FailureMapper`
— so repositories, Cubits/BLoCs and widgets never see an
infrastructure-specific exception type. See
`.agents/skills/error-handling/SKILL.md` for when to add a new
`DomainFailure` subtype (rare — prefer the five that already exist) and how
to map an error to localized copy in the UI.

Cubits/BLoCs must not store `e.toString()` (or otherwise interpolate a
caught exception) into state that a widget renders — a raw exception message
is not localized, not user-appropriate, and leaks implementation detail.
Map the failure to an enum/sealed UI-error value in the Cubit's state
instead, and have the widget switch on it to pick localized copy.

## 10. Routing

The app uses `go_router` via `packages/ui/lib/src/router/app_router.dart`,
built by the **function** `buildAppRouter()` — never memoize its result as a
top-level singleton (this is what makes router tests isolated; see
`.agents/skills/routing/SKILL.md`). Every route is a typed `AppRoute` enum
value, not a string literal.

- A screen that belongs to the app's persistent navigation (bottom nav,
  drawer) is nested inside the `StatefulShellRoute` in `app_router.dart`.
- A screen that needs full immersion (no shell chrome — a checkout flow, a
  media viewer, an active session) is a top-level `GoRoute`, a sibling of
  the `StatefulShellRoute`.
- A route that needs a typed argument uses `state.extra` with a
  redirect-based type guard, not `state.pathParameters` for anything beyond
  a plain id string — see the skill for the pattern.

## 11. Localization (i18n)

`packages/ui` has Flutter localization fully configured via `gen-l10n`.
**No hardcoded user-facing strings are allowed anywhere in `packages/ui/`.**

1. Add the key and its `@key` metadata to `packages/ui/lib/l10n/app_en.arb`
   (and the matching translation to `app_es.arb`).
2. Run `fvm flutter gen-l10n` from `packages/ui/`.
3. Consume it via `context.l10n.yourKey` (see section 13), never
   `AppLocalizations.of(context)!.yourKey` directly.

Do not set `synthetic-package: true` in `l10n.yaml` — that feature has been
removed from Flutter.

## 12. Test doubles

Mocking packages (`mocktail`) and hand-written fakes MUST live under
`test/`, as `dev_dependencies` only. Never add a mocking package to a
package's `dependencies`, and never define a `Mock`/`Fake` class inside
`lib/`. Put a reusable fake/pumper in `test/helpers/` (see
`packages/ui/test/helpers/pump_app.dart`) instead of redeclaring it per
test file.

## 13. Barrel files & imports

Every directory of three or more related files gets a barrel file (e.g.
`entities.dart`, `data_providers.dart`, `presentation.dart`) that exports
its siblings. Each package's root (`lib/domain.dart`, `lib/data.dart`,
`lib/ui.dart`) exports **only** top-level barrels — never reach into
another package's `src/` from outside that package.

Import convention: **relative imports within the same package**,
**`package:` imports across a package boundary**. This is checked by
`tool/check_architecture.dart`, not just style — a relative import can never
accidentally cross a package boundary undetected.

## 14. Flavors & environments

Two build flavors, `dev` and `prod`. `lib/app_environment.dart`'s
`AppEnvironment.flavor` reads `--dart-define=FLAVOR=<dev|prod>`; the native
`--flavor <dev|prod>` selects the Android `productFlavor` / iOS scheme
(`ios/Flutter/*-dev.xcconfig`, `*-prod.xcconfig`). **Both flags are
required on every `flutter run`/`flutter build`, and must always agree** —
use the `.vscode/launch.json` configurations rather than typing them by
hand. See `.agents/skills/flavors-and-flags/SKILL.md` for adding a
per-flavor `FeatureFlag` default (`lib/feature_flag_defaults.dart`).

## 15. Widget build helpers & BuildContext injection

`packages/ui/lib/src/theme/context_extensions.dart` defines
`extension BuildContextX on BuildContext` with `context.theme` (replaces
`Theme.of(context)`) and `context.l10n` (replaces
`AppLocalizations.of(context)!`). If a helper needs another value that's
always derivable from `BuildContext` (a commonly-read provider, for
instance), add a getter there instead of calling `Theme.of`,
`AppLocalizations.of` or `context.read<X>()` ad hoc in many places.

A private `_build*`/helper widget-building method takes, by default, at
most a single `BuildContext context` parameter. Only add a further
parameter for data NOT obtainable from `context` (widget-local state such
as an enum passed down from a `BlocBuilder`'s state). Never pass
`ThemeData`, `AppLocalizations`, or a bloc/cubit instance as an explicit
parameter when `context.theme`/`context.l10n`/`context.read<X>()` inside
the method achieves the same result. This applies recursively: a helper
called by another helper still receives only `BuildContext` plus its own
non-context-derivable data.

## 16. Performance & correctness details worth getting right

- `StatefulShellRoute.indexedStack` keeps every branch mounted and wraps
  inactive ones in `TickerMode(enabled: false)` rather than disposing them.
  An `AnimationController` that calls `..repeat()` unconditionally keeps
  ticking after the user switches tabs — gate it on `TickerMode.of(context)`,
  or skip the animation if it isn't load-bearing.
- Check `if (isClosed) return;` before an async `emit` in a Cubit/BLoC, and
  cancel every stream subscription in `close()`.
- Check `if (!context.mounted) return;` after an `await` before using a
  `BuildContext`.
- Prefer `const` constructors wherever the analyzer allows it (enforced by
  lint, but worth reasoning about directly for widgets rebuilt often).

## 17. Commands

Always run these through `fvm` (see `flutter-fvm` skill) or `dart run`:

| Task | Command |
|---|---|
| Get dependencies | `fvm flutter pub get` (run at the repo root — this is a pub workspace) |
| Format | `fvm dart format -l 100 .` |
| Analyze | `fvm flutter analyze --fatal-infos` |
| Regenerate l10n | `fvm flutter gen-l10n` (from `packages/ui/`) |
| Run every check | `fvm dart run tool/quality_gate.dart` |
| Check architecture boundaries only | `fvm dart run tool/check_architecture.dart` |
| Run all tests | `fvm flutter test` (root), `fvm dart test` (in `packages/domain`), `fvm flutter test` (in `packages/data`, `packages/ui`) |
| Check AI config is in sync | `fvm dart run tool/sync_ai_config.dart --check` |

## 18. Definition of done

A change is complete only when all of the following hold:

- [ ] `fvm dart run tool/quality_gate.dart` exits 0 (format, analyze,
      architecture check, AI-config sync check, tests).
- [ ] Every new entity/provider/repository/Cubit/BLoC/widget/route has a
      test in the same change (section 6).
- [ ] No hardcoded user-facing string in `packages/ui/` (section 11).
- [ ] No `data` import in `packages/ui/`, no `flutter`/`data` import in
      `packages/domain/` (section 2).
- [ ] Before the top-level task is declared finished, the **orchestrating
      session** runs the `code-review` skill's parallel-review protocol
      (`.agents/skills/code-review/SKILL.md`) rather than self-certifying.
      This is the orchestrator's step, not a delegating-forbidden
      subagent's (`architect`, `feature-implementer`, `test-writer`,
      `ui-implementer`) — one of those hands its result back instead of
      running the protocol itself, since running it means dispatching
      `reviewer`/`senior-reviewer`/`review-fixer`, which those agents'
      own rules forbid. A team not using an AI agent for a given change
      satisfies this same checkbox with an ordinary pull-request review
      against `.github/pull_request_template.md`'s checklist — see
      [`docs/without-ai.md`](docs/without-ai.md).

## 19. Skill index

Load the matching skill before starting the task it names — each one has
templates and a worked example, not just prose.

| When you're about to... | Load |
|---|---|
| Bootstrap a fresh app from this template | `bootstrap-project` |
| Add a persistence/network package to `data` | `choose-data-stack` |
| Build a whole new feature end to end | `new-feature` |
| Design an entity/value object | `domain-modeling` |
| Write a data provider implementation | `data-provider` |
| Write a Cubit/BLoC or its state | `state-management` |
| Build a screen | `ui-screen` |
| Add or change a route | `routing` |
| Add or change a user-facing string | `localization` |
| Add a design token or shared widget | `theming` |
| Write tests for any layer | `testing` |
| Design or map a new failure type | `error-handling` |
| Add a feature flag or flavor-specific default | `flavors-and-flags` |
| Run any `flutter`/`dart` command | `flutter-fvm` |
| Write a commit message | `conventional-commits` |
| Review a change before calling it done | `code-review` |
| Interpret `tool/quality_gate.dart` output | `quality-gate` |

## 20. Forbidden patterns

- `get_it`, `injectable`, or any other service locator (section 3).
- A repository **interface** in `domain` (repositories are concrete —
  section 1) or a use-case class.
- `setState` in a feature screen (Cubit/BLoC only — section 3).
- A `Mock`/`Fake` class, or a mocking package dependency, inside `lib/`
  (section 12).
- A hardcoded, user-facing string literal in `packages/ui/` (section 11).
- `e.toString()` (or similar) surfaced into UI state (section 9).
- A relative import that crosses a package boundary, or a `package:`
  import for a file in the *same* package (section 13).
- `packages/ui` depending on `packages/data`, or `packages/domain`
  depending on `flutter` or `packages/data` (section 2).
