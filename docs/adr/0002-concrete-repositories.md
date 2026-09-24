# ADR 0002: Concrete repositories, no repository-interface/use-case layer

## Status

Accepted

## Context

A common Clean Architecture shape in Flutter tutorials and production
codebases alike is: an abstract `XRepository` interface defined in the
domain layer, a concrete `XRepositoryImpl` in the data layer, and a
`UseCase` (or `Interactor`) class per operation that sits between a
Cubit/BLoC and the repository interface. This template's stated goal is
code an AI agent can produce and a human can trace through at
senior-engineer quality from the first prompt — which means the shape of
the architecture has to optimize for **traceability**, not just textbook
purity.

## Decision

`packages/domain` exposes:

- **Data-provider interfaces** (`abstract interface class`, entities only,
  no SQL/HTTP) — the one seam that stays abstract, because it's what lets
  a data provider be faked in a repository test.
- **Concrete repository classes** — constructor-injected with one or more
  data-provider interfaces, holding the orchestration a use-case class
  would otherwise hold (combining providers, applying a rule before
  persisting).

There is **no** repository interface and **no** separate use-case layer
(`AGENTS.md` section 1, and forbidden explicitly in section 20).

## Consequences

- Tracing "what happens when this button is pressed" is Cubit → repository
  → data-provider interface → data-provider implementation: four hops,
  every one of which does something. The interface-plus-use-case shape adds
  two more hops (`UseCase`, `XRepositoryImpl` as a separate indirection
  from `XRepository`), several of them pure pass-through.
- Fewer places for an unnecessary abstraction to hide — a use-case class
  that does nothing but call one repository method is a common smell in
  the shape this template rejected; it can't appear here because there's no
  use-case layer to put it in.
- A repository can't be swapped for a different implementation via DI the
  way an interface-based one could — the template accepts this, since
  `data`-provider interfaces are still the actual seam for testing/swapping
  the *data source* (Drift vs. an in-memory fake, for instance); the
  repository's own orchestration logic is not something this template
  needed to swap independently of its data provider.
- Repository unit tests use a hand-written `Fake*DataProvider implements
  XDataProvider` (see `packages/domain/AGENTS.md` → Testing) rather than
  mocking the repository itself, since the repository is the thing under
  test.
