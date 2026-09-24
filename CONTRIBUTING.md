# Contributing

This file is for people improving **this template itself** — its
architecture, tooling, skills, and agent configuration. If you're building
an app *from* this template, see `AGENTS.md` and
[`docs/getting-started.md`](docs/getting-started.md) instead.

## Proposing a change

- Small fix (typo, broken link, a skill's wording): open a pull request
  directly.
- Anything that changes a convention documented in `AGENTS.md` (a layer
  rule, a forbidden pattern, the DI approach, the review protocol): open an
  issue first describing the change and why, so it can be discussed before
  any code is written. `AGENTS.md` is the contract every downstream AI
  agent and every developer using this template relies on — a silent
  change there is a breaking change for everyone who cloned it.

## Before opening a pull request

Every change, no matter how small, must pass the full quality gate from
the repo root:

```
fvm dart run tool/quality_gate.dart
```

This runs formatting, analysis, the architecture-boundary check
(`tool/check_architecture.dart`), the AI-config sync check
(`tool/sync_ai_config.dart --check`), and every package's test suite. A
pull request that doesn't pass it will not be merged.

## Changing a skill or a subagent

`ai/agents/*.yaml`, `ai/workflows/*.md`, `ai/mcp.yaml` and
`.agents/skills/*/SKILL.md` are the **only** places to edit AI
configuration. Everything else the various tools read —
`.claude/agents/`, `.claude/skills/`, `.codex/agents/`,
`.codex/config.toml`, `.agents/agents/`, `.agents/workflows/`,
`.agents/rules/`, `.agents/mcp_config.json`, `.mcp.json`,
`.opencode/agents/`, `.opencode/.gitignore`, `opencode.jsonc` — is
**generated** from those sources. Each generated file starts with a header
saying so; hand-editing one is pointless, since the next sync silently
overwrites it, and `tool/sync_ai_config.dart --check` will flag the drift
in CI regardless.

Editing `ai/agents/*.yaml` or `.agents/skills/*/SKILL.md` also runs those
files through `tool/sync_ai_config.dart`'s skill-frontmatter validation
(name matches `^[a-z0-9]+(-[a-z0-9]+)*$`, matches its folder name, and a
non-empty description of 1024 characters or fewer) — this is the naming
spec OpenCode and Pi's Agent Skills support both enforce, so a skill that
fails it silently disappears (OpenCode) or loads with a warning (Pi)
instead of failing loudly, which is why the sync script itself refuses to
run rather than leaving that to be discovered later. `.pi/extensions/` is
hand-written, like `tool/hooks/format_changed.dart` — see that file's
header comment and `ai/README.md`'s harness-support table.

To change an agent's role, model tier, or permissions, edit its
`ai/agents/<name>.yaml`. To change a skill's instructions, edit
`.agents/skills/<name>/SKILL.md`. To change the review protocol, edit
`ai/workflows/review.md` — it is the single source the `code-review`
skill/workflow wrappers point at, not duplicated prose per tool. Then
regenerate and verify:

```
fvm dart run tool/sync_ai_config.dart
fvm dart run tool/sync_ai_config.dart --check
```

See `ai/README.md` for the full schema of an agent YAML file and the
tier/access mapping per tool.

## Code style

- `very_good_analysis`, with the exceptions and reasoning documented in
  `analysis_options.yaml` — read that file's comments before assuming a
  disabled lint is an oversight.
- 100-column formatting: `fvm dart format -l 100 .`, not the 80-column
  default.
- English only, everywhere — code, comments, commit messages, documentation.
  A comment explains *why*, never restates *what* the code already says.
- The conventions in `AGENTS.md` (dependency direction, no service locator,
  concrete repositories, sealed failures, the Screen/View split, barrel
  files, relative-vs-`package:` imports) apply to the template's own code
  exactly as they apply to an app built from it — this repository is not
  exempt from its own rules.
- Use the `conventional-commits` skill for commit messages.
