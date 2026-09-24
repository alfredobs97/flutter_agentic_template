---
name: conventional-commits
description: Explains the Conventional Commits format used in this repo, the standard commit types with worked examples using this repo's real scopes, the breaking-change footer, and how types map to semver; load before writing a commit message.
---

# Conventional Commits

Every commit message in this repo follows the Conventional Commits
format:

```
<type>(<scope>): <subject>

[optional body]

[optional footer(s)]
```

- **`<type>`** — what kind of change this is (see the table below).
- **`<scope>`** — the part of the codebase the change lives in, in
  parentheses, lowercase. In this repo the scopes that map to something
  real are: `domain`, `data`, `ui` (the three `packages/`), `tool` (the
  `tool/` scripts — `quality_gate.dart`, `check_architecture.dart`,
  `sync_ai_config.dart`), `ai` (the `ai/` source files that
  `sync_ai_config.dart` generates from), and `docs` (`AGENTS.md`,
  `README.md`, skill files). A change spanning more than one package (a
  new feature touching `domain`, `data` and `ui` together) either picks
  the layer most central to the change or omits the scope entirely —
  don't invent a scope like `feature` or `app` that doesn't correspond to
  a real directory.
- **`<subject>`** — imperative mood, lowercase, no trailing period:
  `add task list screen`, not `Added the task list screen.`.

## Standard types, with real-repo examples

| Type | Use for | Example |
|---|---|---|
| `feat` | A new capability visible to a user or consumer of the package | `feat(ui): add task list screen` |
| `fix` | A bug fix — behavior was wrong, now it's correct | `fix(data): map DriftTimeoutException to ConnectivityFailure` |
| `refactor` | Restructuring code with no behavior change | `refactor(domain): extract sortedTasks getter onto Task` |
| `test` | Adding or fixing tests only, no production code change | `test(data): cover ApiTaskDataProvider's 404 mapping` |
| `docs` | Documentation only — `AGENTS.md`, `README.md`, skill files, doc comments | `docs(ai): clarify when to add a DomainFailure subtype` |
| `chore` | Maintenance with no source or behavior impact (dependency bump, gitignore entry) | `chore(ui): bump go_router to 17.4.0` |
| `ci` | Continuous-integration configuration | `ci(tool): run quality_gate.dart on pull_request` |
| `build` | Build system or packaging (Gradle, Xcode project, pubspec structure) | `build(domain): add domain as a workspace member` |
| `perf` | A change made specifically to improve performance, with no behavior change | `perf(ui): gate AnimationController.repeat on TickerMode` |
| `style` | Formatting/whitespace only — never a lint fix that changes logic | `style(data): run dart format -l 100 on failure_guard.dart` |

If a change fits two types, pick the one that describes its primary
intent — a bug fix that happens to add a regression test is still `fix`,
not `test`.

## Breaking changes

A change that breaks an existing public API (a `domain` entity's
constructor signature, a `data_provider` interface method, an exported
Cubit's public method) is marked one of two ways:

- **`!` after the type/scope**, for a short, self-explanatory break:

  ```
  feat(domain)!: require ClockReader in TaskRepository's constructor
  ```

- **A `BREAKING CHANGE:` footer**, when the break needs its own
  explanation (what broke, and what callers must do about it):

  ```
  refactor(domain): rename Task.due to Task.dueAt

  BREAKING CHANGE: Task.due is renamed to Task.dueAt to match the
  ValidationFailure message key. Update every constructor call and
  copyWith usage in data and ui.
  ```

Both forms can be combined (`!` in the header, plus a `BREAKING CHANGE:`
footer with the detail) when the one-line summary in the header isn't
enough on its own.

## Mapping to semver

Conventional Commits exists so a release tool can derive the next version
number from commit history without a human deciding it by hand:

| Commit contains | Semver bump |
|---|---|
| Only `fix`, `refactor`, `test`, `docs`, `chore`, `ci`, `build`, `perf`, `style` | patch (`0.1.0` → `0.1.1`) |
| At least one `feat` | minor (`0.1.0` → `0.2.0`) |
| Any commit with `!` or a `BREAKING CHANGE:` footer, regardless of type | major (`0.1.0` → `1.0.0`) |

A `feat!` or a `fix` with a `BREAKING CHANGE:` footer both trigger a major
bump — the breaking-change marker outranks the type it's attached to.

## Write the message for the reader, not for yourself

A commit message should describe the change's **effect** — what a caller,
reviewer, or future archaeologist of `git log` needs to know — not
restate the diff. `fix(data): handle timeout in ApiTaskDataProvider` is
worse than `fix(data): map DriftTimeoutException to ConnectivityFailure so
the UI shows the offline message instead of a generic error` only in
length, not in substance: prefer the version that says why the change
matters, but keep the subject line itself short and put the "why" in the
body when it doesn't fit in one line. Never write a subject that just
paraphrases the file list (`fix(data): update failure_guard.dart`) — that
information is already in `git show --stat`.
