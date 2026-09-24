# ADR 0003: Sealed `DomainFailure` + exceptions, not `Either`/`Result`

## Status

Accepted

## Context

Every data-provider implementation wraps an infrastructure package (Drift,
Dio, Firebase, `PlatformException`, ...) whose exception types must never
escape into `domain`, a Cubit/BLoC, or a widget (`AGENTS.md` section 9). A
consistent, type-safe way to represent "this operation failed, and here's
why" needs to exist at that boundary. The two common approaches in the
Dart/Flutter ecosystem are:

1. A **functional `Either<Failure, T>` / `Result<T>` wrapper type**
   (typically from `fpdart` or `dartz`), where every fallible call returns
   a wrapped value that must be `.fold`/`.map`/pattern-matched to unwrap.
2. A **sealed exception hierarchy** thrown/returned at the boundary, caught
   with ordinary `try`/`catch`, and exhaustively handled via Dart's
   `sealed`-aware `switch`.

## Decision

Use a `sealed class DomainFailure`
(`packages/domain/lib/src/failures/domain_failure.dart`) with five
subtypes (`UnexpectedFailure`, `NotFoundFailure`, `ValidationFailure`,
`ConnectivityFailure`, and one more — see the file itself for the current
list). Data providers translate infrastructure exceptions into a
`DomainFailure` via `guard`/`guardStream`
(`packages/data/lib/src/guards/failure_guard.dart`) with a package-specific
`FailureMapper`. No `Either`/`Result` wrapper type is used anywhere in the
codebase.

## Consequences

- **No functional-programming dependency.** No `fpdart`/`dartz` package,
  and no `.fold`/`.map`/`.flatMap` vocabulary required to read an error
  path — a caught `DomainFailure` is handled with a plain `switch`.
- **Exhaustiveness is still guaranteed**, by the Dart analyzer itself: a
  `switch` over a `sealed` type that doesn't cover every subtype is a
  compile error. This is the actual safety property `Either` is usually
  reached for, obtained here without a wrapper type.
- Cubits/BLoCs catch a `DomainFailure` in a plain `try`/`catch` and map it
  to a UI-facing error value in `emit` — ordinary, idiomatic Dart control
  flow, not a monadic chain.
- The corresponding discipline this decision leans on: a Cubit/BLoC must
  never store `e.toString()` (or otherwise interpolate a caught exception)
  into rendered state (`AGENTS.md` section 9, forbidden in section 20) —
  the sealed type only pays off if every catch site actually maps to it
  instead of leaking the raw exception.
- Adding a sixth `DomainFailure` subtype is deliberately treated as rare —
  see `.agents/skills/error-handling/SKILL.md` — since each new subtype
  means a new arm in every exhaustive `switch` across the codebase that
  handles failures.
