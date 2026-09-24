# Building without an AI agent

This template is a plain Flutter Clean Architecture starting point first,
and an AI-agent-ready one second — the two are not in tension. Everything
in [`docs/getting-started.md`](getting-started.md) and
[`docs/architecture.md`](architecture.md) works the same whether or not any
AI tool ever opens this repo. This page is for a Flutter team that wants to
build by hand today, while keeping the option to turn an AI agent on later
at no cost.

## What you can ignore entirely

These paths exist only so Claude Code, OpenAI Codex, Google Antigravity,
OpenCode and Pi have something to read. None of them run any code, add a
dependency, or change how `flutter`/`dart` behaves — you can leave every
one of them alone:

- `ai/` — the canonical source the AI tooling is generated from.
- `.agents/` — skill docs (see below — these are worth reading even without
  AI) plus generated subagents/workflows/rules for Antigravity.
- `.claude/`, `.codex/`, `.opencode/`, `.pi/`, `.mcp.json`, `opencode.jsonc`
  — generated or hand-written config for each specific tool.
- `tool/sync_ai_config.dart` — the generator. `tool/hooks/format_changed.dart`
  and `.pi/extensions/dart-format.ts` are the Claude Code and Pi
  format-on-edit hooks respectively; OpenCode's equivalent is a plain config
  entry (`opencode.jsonc`'s `formatter.dart`), not a separate script.

The one rule that still applies to you even if you never open an AI tool:
**don't hand-edit a file under `.claude/`, `.codex/`, `.opencode/`, or
`.agents/agents|workflows|rules|mcp_config.json`** — every one of them
starts with a "GENERATED FILE — DO NOT EDIT" header. If you never touch
`ai/` or `.agents/skills/` either, `fvm dart run tool/sync_ai_config.dart
--check` (part of the quality gate) always passes on its own — there is
nothing for you to keep in sync.

## `AGENTS.md` is the team's style guide, not just an AI prompt

Despite the name and its "for agents" framing, `AGENTS.md` (plus one
`packages/*/AGENTS.md` per package) is where every convention in this
codebase is written down: the dependency-direction rules, state
management, error handling, routing, localization, testing. Read it the
way you'd read a `CONTRIBUTING.md` or an internal engineering handbook —
because that's what it is. A human contributor gets exactly the same
value out of it an AI agent does.

## Using the skill docs as recipes

Every file under `.agents/skills/<name>/SKILL.md` is a worked, step-by-step
guide with real code for one kind of task — written so an AI agent doesn't
have to guess the pattern, which also means it's a complete recipe for a
human who doesn't want to guess either. Open the matching one when you're
about to do the task in the left column:

| Task | Skill doc |
|---|---|
| Bootstrap a fresh app from this template | `.agents/skills/bootstrap-project/SKILL.md` |
| Add a persistence/network package to `packages/data` | `.agents/skills/choose-data-stack/SKILL.md` |
| Build a whole new feature end to end | `.agents/skills/new-feature/SKILL.md` |
| Design an entity or value object | `.agents/skills/domain-modeling/SKILL.md` |
| Write a data-provider implementation | `.agents/skills/data-provider/SKILL.md` |
| Design a Cubit/BLoC and its state | `.agents/skills/state-management/SKILL.md` |
| Build a screen (Screen/View split, loading/empty/error states) | `.agents/skills/ui-screen/SKILL.md` |
| Add or change a `go_router` route | `.agents/skills/routing/SKILL.md` |
| Add or change a user-facing string | `.agents/skills/localization/SKILL.md` |
| Add a design token or shared widget | `.agents/skills/theming/SKILL.md` |
| Write a test for any layer | `.agents/skills/testing/SKILL.md` |
| Design or map a new `DomainFailure` | `.agents/skills/error-handling/SKILL.md` |
| Add a feature flag or flavor-specific default | `.agents/skills/flavors-and-flags/SKILL.md` |
| Run any `flutter`/`dart` command | `.agents/skills/flutter-fvm/SKILL.md` |
| Write a commit message | `.agents/skills/conventional-commits/SKILL.md` |
| Interpret `tool/quality_gate.dart` output | `.agents/skills/quality-gate/SKILL.md` |

Nothing in these files is agent-specific instruction-following prose — they
read like a senior teammate's onboarding notes, with the reasoning ("why
this shape, not the obvious one") included.

## The human equivalent of the AI code-review step

`AGENTS.md` section 18 (Definition of Done) asks an AI-orchestrated task to
run the `code-review` skill's two-blind-reviewer protocol
(`.agents/skills/code-review/SKILL.md`) before calling itself finished. If
your team isn't using an AI agent for a given change, the equivalent step
is an ordinary pull request review against the same checklist: does it
pass `fvm dart run tool/quality_gate.dart`, does every new
entity/provider/repository/Cubit/widget/route have a test, are there no
hardcoded strings in `packages/ui/`, does the dependency direction hold —
see `.github/pull_request_template.md`, which is the same checklist in
PR-description form. The two-reviewer AI protocol exists to catch what a
single reviewer anchors on and misses; a human PR review with a second
pair of eyes on the diff is the same idea, and satisfies the same
checkbox.

## Turning AI on later

There's no setup step waiting for you. Open the repo in Claude Code,
Codex, Antigravity, OpenCode, or Pi whenever you want to, and it reads
`AGENTS.md` and the matching skills/subagents immediately — see
[`docs/ai-workflow.md`](ai-workflow.md) for a per-tool quick reference and
some starter prompts.
