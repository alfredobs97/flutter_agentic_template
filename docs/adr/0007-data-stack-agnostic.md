# ADR 0007: `packages/data` ships with no pre-installed persistence/network stack

## Status

Accepted

## Context

This template is meant to be a generic starting point for many different
apps, which will inevitably want different backends: some will use Drift
for local-only storage, some Firebase, some a REST API via Dio, some
Supabase, and so on. Pre-installing any one of these as a default would
mean every app built from the template either uses that default or spends
its first real feature ripping it out and replacing it — exactly the
"delete the sample feature first" friction the template's empty-skeleton
philosophy (see the README) is designed to avoid.

## Decision

`packages/data/pubspec.yaml` depends on `domain` and `uuid` only — no
Drift, no Dio, no Firebase SDK, no data-provider implementation checked in.
`packages/data/AGENTS.md` states this explicitly: run
`.agents/skills/choose-data-stack/SKILL.md` before writing the first data
provider. That skill adds the chosen package as a dependency, a
stack-specific `FailureMapper` mapping that package's exceptions to
`DomainFailure`, a provider skeleton wrapping it, and a test harness suited
to the stack (an in-memory database instance, or a mocked HTTP client,
depending on what was chosen).

## Consequences

- No app built from this template inherits a backend decision it didn't
  make — the first thing `choose-data-stack` does is make that decision
  explicit and deliberate, once, for the whole app.
- `packages/domain`'s data-provider interfaces (`abstract interface class`,
  entities only) are the seam this design leans on: they're written before
  any concrete stack is chosen, and stay valid regardless of which stack
  ends up implementing them.
- An AI agent asked to "add a Tasks feature" before a stack has been chosen
  must stop and flag it (see `ai/agents/architect.yaml`'s explicit
  instruction to check `packages/data/pubspec.yaml` and refuse to invent a
  stack) rather than silently picking one — this is a deliberate friction
  point, not an oversight.
- The cost: a brand-new clone of the template cannot persist data at all
  until `choose-data-stack` has run once. This is accepted as strictly
  better than the alternative of a default stack quietly shaping every
  app's architecture before its developer has made that choice themselves.
