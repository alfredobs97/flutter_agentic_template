# `data` — layer rules

See the root `AGENTS.md` first — this file only adds detail specific to
this package.

## What belongs here

- **Data-provider implementations** (`lib/src/data_providers/`):
  `implements` an interface from `package:domain`, wraps your chosen
  storage/network package, and translates its exceptions into a
  `DomainFailure` via `guard`/`guardStream`
  (`lib/src/guards/failure_guard.dart`) with a `FailureMapper` specific to
  that package. Never let a Drift/Dio/Firebase exception type escape this
  package.
- **Data sources** (`lib/src/data_sources/`): infrastructure the providers
  share (a Dio `Client` instance, a Drift `AppDatabase`, ...).
- **Guards** (`lib/src/guards/`): the `guard`/`guardStream`/`FailureMapper`
  seam every provider method routes through.
- **Models/mappers**, if your chosen stack needs a DTO distinct from its
  generated row/response type: keep the `_mapToEntity`/`_mapFromEntity`
  functions private to the provider file that uses them, not a shared
  "mapper layer".

## This package ships with no storage/network dependency installed

Run `.agents/skills/choose-data-stack/SKILL.md` before writing your first
provider. It adds the dependency, a stack-specific `FailureMapper`, a
provider skeleton, and a test harness (in-memory DB, or a mocked HTTP
client, depending on the stack).

## What does NOT belong here

- Anything importing `package:flutter` or any `package:ui` file — `data`
  has no UI concerns and `ui` must never import `data` in return (root
  `AGENTS.md` section 2).
- A repository — repositories live in `domain` (root `AGENTS.md` section 1).

## Testing

`flutter_test` (kept for parity with the rest of the workspace, and because
most storage stacks pull in Flutter-plugin dependencies). Prefer a real,
ephemeral instance of your stack over mocking it (e.g. an in-memory
database) — `choose-data-stack`'s generated test harness sets this up.
