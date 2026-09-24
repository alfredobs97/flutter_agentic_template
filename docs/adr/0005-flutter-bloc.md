# ADR 0005: `flutter_bloc` (Cubit/Bloc) for state management

## Status

Accepted

## Context

The presentation layer (`packages/ui`) needs a single, consistent state
management approach — consistent both so a human can predict where state
lives in any feature, and so an AI agent has exactly one pattern to
imitate rather than a choice to make (and potentially make inconsistently)
per feature. Flutter's ecosystem offers several established options
(`provider` alone, `riverpod`, `flutter_bloc`, raw `ChangeNotifier`,
`setState`-based local state).

## Decision

Use **`flutter_bloc`** (`^9.1.1`) exclusively, in both its `Cubit` and full
`Bloc` forms — `.agents/skills/state-management/SKILL.md` covers which of
the two to pick for a given piece of state. `setState` is forbidden inside
a feature screen (`AGENTS.md` section 3, forbidden in section 20); all
screen state flows through a Cubit or BLoC.

Two further conventions ride on top of this choice:

- A screen that owns a Cubit is split into a public `XScreen` (creates the
  Cubit via `BlocProvider(create: ...)`) and a private `_XView` (consumes
  it via `BlocBuilder`) — the Screen/View split (`AGENTS.md` section 8).
- A Cubit/BLoC provided once at the app root (`lib/app.dart`, e.g.
  `FeatureFlagCubit`) lives in `packages/ui/lib/src/app_blocs/`, distinct
  from a screen-scoped Cubit created inside that screen's own `build`.

## Consequences

- One state-management vocabulary across the entire `ui` package —
  `bloc_test` covers every Cubit/BLoC test the same way
  (`packages/ui/AGENTS.md` → Testing), and an AI agent building a new
  feature has a single, well-established pattern to imitate rather than a
  choice between several equally-valid ones.
- `flutter_bloc`'s discipline around explicit `State` classes and
  `emit`-based transitions pairs naturally with the sealed `DomainFailure`
  decision (ADR 0003): a Cubit's `try`/`catch` around a repository call
  maps a caught `DomainFailure` to a UI-facing state value directly.
- The template accepts `flutter_bloc`'s comparative verbosity (an explicit
  state class, `copyWith` or a sealed hierarchy per Cubit) over a lighter
  alternative like `provider`+`ChangeNotifier`, because that same
  explicitness is what makes a Cubit's state transitions straightforward to
  unit-test with `bloc_test` in isolation from the widget tree.
- Two performance/correctness details specific to this choice are called
  out directly in `AGENTS.md` section 16 and checked in code review: an
  `if (isClosed) return;` guard before an async `emit`, and cancelling
  every stream subscription in `close()`.
