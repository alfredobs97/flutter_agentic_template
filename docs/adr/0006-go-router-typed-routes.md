# ADR 0006: `go_router` with typed routes and a router-building function

## Status

Accepted

## Context

The app needs declarative, deep-link-capable routing with support for a
persistent bottom-navigation/drawer shell alongside full-immersion screens
(a checkout flow, a media viewer) that skip that shell entirely. It also
needs to be testable in isolation — a router test should be able to build a
fresh router per test without state leaking in from a previous test via a
shared singleton.

## Decision

Use **`go_router`** (`^17.3.0`), built by a plain **function**,
`buildAppRouter()` (`packages/ui/lib/src/router/app_router.dart`) — never
memoized as a top-level singleton. `lib/bootstrap.dart` calls it exactly
once per app run and passes the result down to `App`, rather than
`app_router.dart` caching a single instance for the whole process lifetime.

Further conventions:

- Every route is a typed `AppRoute` enum value, never a raw string literal
  scattered across `context.go(...)` call sites.
- A screen that belongs to the app's persistent navigation is nested inside
  the `StatefulShellRoute` in `app_router.dart`; a screen that needs full
  immersion (no shell chrome) is a top-level `GoRoute`, a sibling of the
  `StatefulShellRoute`.
- A route needing a typed argument uses `state.extra` with a
  redirect-based type guard, not `state.pathParameters` for anything beyond
  a plain id string.

## Consequences

- **Router tests are isolated by construction**: each test calls
  `buildAppRouter()` itself and gets a fresh `GoRouter`, with no risk of a
  previous test's navigation state (current location, shell branch index)
  leaking in via a shared singleton — a common source of flaky router
  tests when a router is memoized globally.
- A typed `AppRoute` enum value catches a typo'd route name at compile
  time, where a string literal would only fail at runtime navigation.
- The Shell-vs-top-level split (`AGENTS.md` section 10) keeps
  `StatefulShellRoute.indexedStack`'s "every branch stays mounted" behavior
  intentional rather than accidental — see `AGENTS.md` section 16 for the
  `TickerMode`-gating consequence this has for any branch running an
  unconditional animation.
- `go_router`'s own learning curve (shell routes, redirects, `state.extra`)
  is accepted as the cost of getting typed navigation, deep linking, and
  nested-shell support without hand-rolling any of the three.
