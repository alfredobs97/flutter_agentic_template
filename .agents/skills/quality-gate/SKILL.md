---
name: quality-gate
description: Explains the contract of fvm dart run tool/quality_gate.dart (its steps, exit codes, and how to read a failure from any step, including tool/check_architecture.dart and tool/sync_ai_config.dart --check), and states that it is the required last step before calling any implementation task done; load before running the quality gate or interpreting its output.
---

# Interpreting `tool/quality_gate.dart`

`fvm dart run tool/quality_gate.dart` is the single command that answers
"is this change done" (root `AGENTS.md` section 18, Definition of Done).
Run it as the **last step** before declaring any implementation task
finished — not as a substitute for running the individual checks while
iterating, but as the final, authoritative gate.

## Contract

The script runs a fixed sequence of steps, in this order. Unlike a typical
CI script, it does **not** stop at the first failure — it runs every step
regardless of earlier results, then prints one summary covering all of
them. This matters: read the *whole* summary, not just the first failure,
since a later step can fail for a reason unrelated to an earlier one, and
stopping after fixing the first-reported failure can still leave the gate
red.

1. **Format check** — `fvm dart format -l 100 --set-exit-if-changed .`
   (or equivalent). Fails if any file isn't already formatted at 100
   columns; does not silently reformat for you.
2. **Analyze** — `fvm flutter analyze --fatal-infos`. Fails on any
   analyzer error, warning, *or* info-level lint (`--fatal-infos` is
   stricter than the default, which only fails the build on errors).
3. **Architecture-boundary check** — `fvm dart run tool/check_architecture.dart`
   (see section below). Fails on a forbidden cross-package import.
4. **AI-config sync check** — `fvm dart run tool/sync_ai_config.dart --check`
   (see section below). Fails if `ai/` source files and the generated
   per-tool config files have drifted apart.
5. **Tests** — `fvm dart test tool/test` (the fixture suite for
   `tool/check_architecture.dart` and `tool/sync_ai_config.dart` — not
   discovered by `fvm flutter test` at the root, since Flutter's test
   runner only looks under `test/`, so this step exists specifically so
   those two scripts' own tests are part of "is this change done"), then
   the full test suite across the workspace (root, `packages/domain`,
   `packages/data`, `packages/ui`).

**Exit codes**: `0` means every step passed — the change satisfies the
Definition of Done's first checkbox. Any non-zero exit means at least one
step failed; the summary table at the end names **every** failed step, and
full output (stdout/stderr) is printed for each one below the table — read
the whole summary before fixing anything, since it tells you up front
whether you're dealing with one isolated failure or several unrelated
ones. Do not treat a partial run (e.g. you manually ran only `dart format`)
as equivalent to the gate passing — a step you didn't run could still be
failing.

Running the gate is not optional busywork gating a task that already
looks correct — it is the last item in `AGENTS.md` section 18's
Definition of Done, alongside per-layer tests, no hardcoded UI strings,
and correct dependency direction. A task is not complete until this
command exits `0`.

## Reading a `tool/check_architecture.dart` failure

This step enforces the dependency rules in root `AGENTS.md` section 2 —
`domain` cannot import `flutter`/`data`, `ui` cannot import `data`, no
relative import may cross a package boundary, no `package:` import may
reach into another package's `src/`. A failure names three things:

- **The file** that contains the forbidden import.
- **The forbidden import** itself (the exact `import` line).
- **Which `AGENTS.md` rule it violates** (e.g. "ui must not import data —
  see AGENTS.md section 2").

Example of the shape to expect:

```
FAIL packages/ui/lib/src/features/tasks/bloc/task_list_cubit.dart
  forbidden import: package:data/data.dart
  rule: packages/ui must never import packages/data (AGENTS.md § 2)
```

The fix is almost always structural, not a suppression: if a Cubit in
`ui` needs data, it must go through a repository from `domain` injected
via constructor — never a `data` provider directly, and never `data`
itself (see `packages/ui/AGENTS.md` → "What does NOT belong here"). If
the failure is a relative import crossing a package boundary, change it
to a `package:` import instead (root `AGENTS.md` section 13); if it's a
`package:` import for a file inside the *same* package, change it to a
relative import.

## Reading a `tool/sync_ai_config.dart --check` failure

This repo's AI-facing configuration is authored once under `ai/` (agent
definitions, workflows, MCP config) plus `.agents/skills/*/SKILL.md` (skill
docs), and *generated* into every tool's own expected location:
`.claude/agents/`, `.claude/skills/` (a verbatim mirror of
`.agents/skills/`, since Claude Code doesn't read that path natively),
`.claude/settings.json`, `.codex/`, `.agents/agents|workflows|rules|mcp_config.json`,
`.opencode/`, and `opencode.jsonc` — see `ai/README.md`'s "Edit here →
generated there" mapping for the full list, including which tools read a
source file natively and need no copy at all. A `--check` failure means a
source file was edited but the generated files were not regenerated to
match — the two are now out of sync, so each tool would see a different,
stale configuration.

**The fix:**

```bash
fvm dart run tool/sync_ai_config.dart
```

then re-run the gate:

```bash
fvm dart run tool/quality_gate.dart
```

**Never hand-edit a generated file** under `.claude/`, `.codex/`,
`.opencode/`, `opencode.jsonc`, or `.agents/agents|workflows|rules|mcp_config.json`
directly — those are build output, including `.claude/settings.json` and
`.agents/rules/00-core.md`, which are templated inside
`tool/sync_ai_config.dart` itself rather than read from a separate source
file. Editing a generated file directly fixes the symptom for one tool
while leaving the real source (and the other tools' generated files)
stale, and the next `sync_ai_config.dart` run overwrites your hand-edit
anyway. If a generated file is wrong, the fix is always in `ai/` or
`.agents/skills/`, followed by regenerating.

One limitation `--check` does **not** catch: deleting or renaming a skill
folder or an `ai/agents/*.yaml` file leaves its old generated counterparts
behind (e.g. a stale `.claude/skills/<old-name>/`) — regenerating only adds
and updates paths, it never removes one for a source that's gone. Delete
the corresponding generated path(s) by hand in that case (see the
generator's own "KNOWN LIMITATION" comment).

## Practical workflow

- While iterating on a single layer, it's fine to run the narrower
  command directly (`fvm flutter analyze --fatal-infos`,
  `fvm flutter test` in the package you're touching) for a faster
  feedback loop — see the `flutter-fvm` skill.
- Before calling a task done, run the full gate, not the narrower
  commands individually — it also catches drift between layers (a stale
  `ai/` file, a boundary violation introduced by a change to a *different*
  file than the one you were editing) that a single narrow check won't.
- If the gate fails, fix every step the summary lists as failed (there is
  often more than one — the gate does not stop at the first), then re-run
  the whole gate from the top rather than assuming the fixed steps are now
  clean — a fix for one step (e.g. reformatting) can occasionally surface a
  previously-masked failure in another step you already "fixed".
