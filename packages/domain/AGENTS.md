# `domain` — layer rules

See the root `AGENTS.md` first — this file only adds detail specific to
this package.

## What belongs here

- **Entities** (`lib/src/entities/`): pure Dart, `Equatable`, hand-written
  `copyWith`. Business rules that belong to the entity itself (validation,
  derived getters, state transitions) are methods here, not scattered
  across Cubits. See `entities.dart` for the sentinel/variant/`sortedX`
  conventions.
- **Data-provider interfaces** (`lib/src/data_providers/`): `abstract
  interface class`, expressed purely in terms of entities — no SQL, no
  HTTP, no mention of a specific package.
- **Repositories** (`lib/src/repositories/`): concrete classes, constructor-
  injected with one or more data-provider interfaces. Holds orchestration
  (combining providers, applying a rule before persisting) — the same job a
  use-case class would do in a different architecture.
- **Failures** (`lib/src/failures/`): the sealed `DomainFailure` hierarchy.
  Add a new subtype only when a caller genuinely needs to react to it
  differently — see `.agents/skills/error-handling/SKILL.md`.

## What does NOT belong here

- Anything importing `flutter`, `dart:io`, or a storage/network package —
  `tool/check_architecture.dart` rejects these.
- A `data_provider` **implementation** — that's `packages/data`'s job.
- A repository **interface** — repositories are concrete here, by design
  (see root `AGENTS.md` section 1).

## Testing

Pure `package:test` (not `flutter_test` — this package has no Flutter
dependency). A repository test uses a hand-written
`Fake*DataProvider implements XDataProvider` that stores data in memory,
not a mocking package (`domain/pubspec.yaml` has no `mocktail`).
