# ADR 0001: Dart pub workspaces (not Melos) for the monorepo

## Status

Accepted

## Context

The template splits the codebase into a root app and three local packages
(`packages/domain`, `packages/data`, `packages/ui`) to enforce Clean
Architecture layer boundaries structurally, not just by convention (see
`AGENTS.md` section 1-2). Some mechanism is needed to resolve dependencies
across these four `pubspec.yaml` files as one unit, rather than requiring a
separate `pub get` (and separate `.dart_tool/`, separate lockfile) per
package.

The two realistic options were:

1. **Melos**, the de-facto standard tool for Flutter/Dart monorepos —
   provides bootstrapping, cross-package scripts, versioning and publishing
   orchestration.
2. **Dart's native pub workspaces** (`workspace:` field in the root
   `pubspec.yaml`, `resolution: workspace` in each member package),
   available since Dart 3.5.

## Decision

Use native Dart pub workspaces. The root `pubspec.yaml` declares:

```yaml
workspace:
  - packages/domain
  - packages/data
  - packages/ui
```

and each package's own `pubspec.yaml` sets `resolution: workspace`. A
single `fvm flutter pub get` at the repo root resolves all four
`pubspec.yaml` files together into one `pubspec.lock`.

## Consequences

- No extra tool to install, pin a version of, or document for a developer
  (or an AI agent) picking up this template — pub workspaces are part of
  the Dart SDK the project already depends on.
- No monorepo-scripts DSL to learn; every command in `AGENTS.md` section 17
  is a plain `fvm flutter`/`fvm dart` invocation.
- The template gives up Melos's independent package versioning/publishing
  orchestration and its `melos run` script registry. Neither is needed
  here: none of the three packages is published independently
  (`publish_to: 'none'` in all four `pubspec.yaml` files), and
  `tool/quality_gate.dart` already plays the role a Melos script would.
- If a future need genuinely requires Melos-specific features (independent
  publishing, cross-repo package sharing), adding Melos on top of an
  existing pub workspace is a strictly additive change, not a migration —
  this decision doesn't foreclose it, it just doesn't reach for it
  pre-emptively.
