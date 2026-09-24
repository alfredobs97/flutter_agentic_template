# ADR 0004: Manual DI via `RepositoryProvider`, no service locator

## Status

Accepted

## Context

Repositories and other cross-cutting dependencies need to be constructed
once and made available throughout the widget tree.
Flutter apps commonly reach for a service locator package (`get_it`,
`injectable`) for this: dependencies are registered against a global
container at startup and resolved by type at the point of use, anywhere in
the codebase, without needing to be threaded through constructors.

## Decision

Use **manual constructor injection**, wired exactly once in
`lib/bootstrap.dart` and exposed to the widget tree via
`RepositoryProvider`/`MultiRepositoryProvider` at the root of the tree
(`lib/app.dart`). No `get_it`, `injectable`, or other service locator is
used anywhere in the codebase (`AGENTS.md` section 3, forbidden explicitly
in section 20) unless a user explicitly asks for one for their own app.

Every repository is built in `lib/bootstrap.dart`'s `bootstrap()` function,
passed as a named constructor parameter into `App`, and exposed via a
matching `RepositoryProvider<T>.value` entry in `App.build()`
(`lib/app.dart`). A Cubit/BLoC that needs a repository reads it via
`context.read<XRepository>()` at the point it's created — never a global
locator call.

## Consequences

- **`lib/bootstrap.dart` *is* the dependency graph.** Every repository, in
  construction order, with its constructor arguments visible in one file —
  answering "what does `TaskRepository` actually depend on, and is it
  registered?" never requires running the app or grepping for a
  `registerLazySingleton` call site; it's a single file, read top to
  bottom.
- `lib/bootstrap.dart` is also the one file in the codebase that imports
  both `packages/data` and `packages/ui` (the composition root, per
  `AGENTS.md` section 2) — keeping DI wiring there means the
  data/ui-crossing code and the DI wiring are the same code, not two
  separate concerns to keep in sync.
- No runtime "unregistered type" failure class exists — a missing
  `RepositoryProvider` entry is a `ProviderNotFoundException` at the exact
  `context.read<T>()` call site that needs it, immediately traceable to a
  missing line in `lib/app.dart`, rather than a locator resolution failure
  that could originate from any registration call anywhere in the app.
- The cost: every new repository requires one line in `bootstrap()`, one
  named parameter on `App`, and one `RepositoryProvider.value` entry —
  three small, explicit edits instead of one locator registration call.
  This template treats that as a feature, not friction: each edit is a
  compile-checked constructor parameter, not a runtime type lookup that
  only fails when exercised.
