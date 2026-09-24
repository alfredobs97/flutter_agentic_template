# `ai/` — canonical AI configuration

This directory is the **single source of truth** for every subagent, MCP
server, and workflow used with this template. Everything else the various
tools read (`.claude/agents/`, `.claude/skills/`, `.codex/agents/`,
`.codex/config.toml`, `.agents/agents/`, `.agents/workflows/`,
`.agents/rules/`, `.agents/mcp_config.json`, `.mcp.json`, `.opencode/agents/`,
`.opencode/.gitignore`, `opencode.jsonc`) is **generated** from this
directory plus `.agents/skills/` by `tool/sync_ai_config.dart`.

**Pi is the one harness this directory does not render anything for.** Pi
has no subagent or MCP concept to target — see the "Harness support" table
below — so there is nothing here for it beyond the `AGENTS.md`/skills
support every harness gets. Its one piece of tool-specific config,
`.pi/extensions/dart-format.ts`, is hand-written, the same as Claude Code's
`tool/hooks/format_changed.dart`.

## Harness support

| Capability | Claude Code | Codex | Antigravity | OpenCode | Pi |
|---|---|---|---|---|---|
| `AGENTS.md` (root + per-package) | native¹ | native¹ | native¹ | native (walks up from the file read) | root only — walks up from cwd, never down into `packages/*/`; see AGENTS.md §1 |
| `.agents/skills/` | copied to `.claude/skills/` | native | native | native (also reads the `.claude/skills/` copy — expect a skill to appear twice) | native, once the project is trusted (`pi --approve`) |
| Subagents | `.claude/agents/` | `.codex/agents/*.toml` | `.agents/agents/` | `.opencode/agents/` | none — out of scope for this template |
| MCP (Dart MCP server) | `.mcp.json` | `.codex/config.toml` | `.agents/mcp_config.json` | `opencode.jsonc`'s `mcp` | none — Pi has no MCP support; skills already shell out to `fvm` directly |
| Format-on-edit | `.claude/settings.json` PostToolUse hook → `tool/hooks/format_changed.dart` | none | none | `opencode.jsonc`'s `formatter.dart` | `.pi/extensions/dart-format.ts` |

¹ "native" here means each tool's docs advertise `AGENTS.md` support; whether
a given version actually discovers a *nested* `packages/*/AGENTS.md` by
walking down from the session's start directory (rather than only up from a
file it happens to open) is not independently verified per tool/version
here. AGENTS.md §1's "read the package's own AGENTS.md before editing in
it" instruction is the safety net that makes this not matter — an agent
that follows it gets the package-level rules regardless of whether its
harness would have discovered them on its own.

Do not hand-edit a generated file — it starts with a header saying so, and
your edit will be silently overwritten (and `--check` mode will flag the
drift in CI). Edit the source here instead, then regenerate:

```
fvm dart run tool/sync_ai_config.dart
```

## Layout

- `agents/*.yaml` — one file per subagent, in a tool-neutral schema (see
  below). Rendered into `.claude/agents/*.md`, `.codex/agents/*.toml`,
  `.agents/agents/*.md` and `.opencode/agents/*.md`.
- `workflows/*.md` — multi-agent protocols (currently just the parallel
  code-review pipeline), written once as the substance. Rendered into
  `.agents/workflows/<name>.md` for Antigravity's native `/name` workflow
  command. The matching skill in `.agents/skills/<name>/` (used natively by
  Codex, OpenCode and Pi, and copied to `.claude/skills/` for Claude) is the
  short, tool-specific "how to run this here" wrapper — it points at the
  workflow file for the actual protocol rather than duplicating it, so the
  protocol itself is edited in exactly one place.
- `mcp.yaml` — every MCP server this template knows about, with **only
  environment variable names**, never secret values. Rendered into
  `.mcp.json` (Claude, `${VAR}` expansion), `.codex/config.toml`
  (`env_vars = [...]`), `.agents/mcp_config.json` (Antigravity) and
  `opencode.jsonc`'s `mcp` block (`{env:VAR}` expansion). Not rendered for
  Pi — it has no MCP support (see the harness-support table above).

  Claude Code is the one tool where "disabled by default" isn't a field
  inside the MCP config file itself: a project `.mcp.json` has no
  per-server `disabled` key Claude Code actually reads (a feature request
  for one was closed as not implemented). A server with
  `enabled_by_default: false` here is instead listed in the generated
  `.claude/settings.json`'s `disabledMcpjsonServers` — see
  `_renderClaudeSettings` in `tool/sync_ai_config.dart`. Codex and
  Antigravity/OpenCode each do have their own working per-server field
  (`enabled = false` / `"disabled": true`), which is why only Claude's
  renderer needs this extra indirection.

## Agent schema (`agents/*.yaml`)

```yaml
name: reviewer                # kebab-case, matches the rendered file's name
description: >                # one paragraph: role + when the orchestrator triggers it
  ...
access: read-only             # read-only | run-only | write — maps to each tool's permission model
tier: standard                # deep | standard | fast — maps to each tool's model tiers
skills: [code-review]         # skill names this agent should load at start-up (Claude Code and Antigravity render this; OpenCode and Codex don't take a per-agent skills field, so it's a no-op there)
prompt: |
  <the agent's full system prompt, in second person, tool-neutral>
```

`tier` → model mapping (`tool/sync_ai_config.dart` is the source of truth
for the exact ids — check it before assuming a mapping below is current):

| tier | Claude Code | Codex | Antigravity | OpenCode |
|---|---|---|---|---|
| deep | opus | (highest available reasoning effort) | pro | — |
| standard | sonnet | (default reasoning effort) | flash | — |
| fast | haiku | (low reasoning effort) | flash | — |

OpenCode agents render with no `model` field on purpose — `tier` has no
OpenCode mapping today, so a generated `.opencode/agents/*.md` always runs
on the session's own model. Set `agent.<name>.model` in your own
`~/.config/opencode/opencode.json` if you want per-agent model tiers there;
this template doesn't prescribe one.

`access` → permission mapping:

| access | Claude Code | Codex | Antigravity | OpenCode |
|---|---|---|---|---|
| read-only | `tools: Read, Grep, Glob, Bash` | `sandbox_mode = "read-only"` | read-only tool allow-list | `permission: {edit: deny, task: deny, webfetch: deny}` |
| run-only | `tools: Read, Grep, Glob, Bash` (same as read-only) | `sandbox_mode = "workspace-write"` | read-only tool allow-list (same as read-only) | same as read-only |
| write | `tools: *` (or an explicit list — see the agent's yaml) | default sandbox | full tool allow-list | `permission: {task: deny}` |

Every OpenCode access level denies `task` (OpenCode's name for subagent
dispatch), regardless of `access` — each agent's own prompt already says
"do NOT spawn or delegate to a subagent" (see `ai/agents/*.yaml`), and this
makes that rule structural instead of instruction-only, mirroring the
reasoning behind Codex's `sandbox_mode` distinction above.

`run-only` exists for exactly one situation: an agent that must never edit
a repository file itself, but whose entire job is *running* a command
that writes transient build/cache output as a side effect (`quality-guardian`
running `fvm dart run tool/quality_gate.dart`, which touches `.dart_tool/`
and `build/` via `flutter analyze`/`flutter test`). For Claude Code and
Antigravity this is identical to `read-only` — neither ever gave those
agents an *editing* tool, and `Bash`/`run_command` was always enough to
run a subprocess that writes artifacts. Codex is the one tool where this
matters: its `sandbox_mode = "read-only"` is an OS-level filesystem
restriction, not just a missing-editing-tool restriction — it blocks
every write a subprocess makes too, including build/test output, which
would make `quality-guardian` unable to ever run the gate it exists to
run. Use `read-only` for an agent that truly never needs to write
anything, anywhere (`reviewer`, `senior-reviewer`); use `run-only` only
for an agent in `quality-guardian`'s specific situation.

## Why not just hand-write `.claude/agents/*.md` three times?

Because it drifts. A rule fixed in the Claude version and forgotten in the
Codex version is worse than no rule — an agent that behaves differently
per tool is a trap for whoever picks up this template next. One source,
one generator, `--check` in CI.
