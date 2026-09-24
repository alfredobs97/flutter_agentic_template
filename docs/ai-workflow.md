# Working with AI agents: practical walkthroughs

This page walks through what actually happens, skill by skill and agent by
agent, when you give this template's AI setup a realistic prompt. For the
schema behind these skills/agents (and how they stay in sync across Claude
Code, Codex, Antigravity and OpenCode — see `ai/README.md`'s harness-support
table for exactly what each one, including Pi, does and doesn't get) see
`ai/README.md`; for the architectural "why" behind the conventions they
enforce, see [`docs/architecture.md`](architecture.md).

## Quick reference: doing this in your tool

| | Claude Code | Codex | Antigravity | OpenCode | Pi |
|---|---|---|---|---|---|
| Run a skill | say what you want; the matching skill loads automatically (or invoke it explicitly, e.g. "run the `new-feature` skill") | same — skills load from `AGENTS.md`-adjacent context automatically | same, or the native `/code-review` workflow command for the review protocol | same | same, once the project is trusted (`pi --approve`) |
| Dispatch a named subagent | "use the `architect` subagent to plan this" (or let a non-trivial request trigger it automatically) | same phrasing | same | same | not supported — no subagent concept, see `ai/README.md` |
| Run the code-review protocol | ask to "review my last change" or invoke the `code-review` skill | same | `/code-review` workflow | same | not supported (no subagents to orchestrate) |
| MCP servers available | Dart MCP server (on by default); Figma (opt-in, see `ai/mcp.yaml`) | same, via `.codex/config.toml` | same, via `.agents/mcp_config.json` | same, via `opencode.jsonc`'s `mcp` block | none — Pi has no MCP support |
| Format-on-edit hook | `.claude/settings.json` PostToolUse → `tool/hooks/format_changed.dart` | none | none | `opencode.jsonc`'s `formatter.dart` | `.pi/extensions/dart-format.ts` |

Three starter prompts to try against a fresh clone (any of the tools above):

- *"Run the `bootstrap-project` skill to rename this template to `acme_app`."*
- *"I want to use Drift for persistence — run `choose-data-stack`."*
- *"Build a Tasks feature: list, detail, and create screens, backed by
  Drift. Then review the change before you call it done."* — this is
  Example 1 below, end to end, including the review protocol from
  Example 2.

## When to run the full review protocol

The two-blind-reviewer protocol (Example 2) is real cost, not free
polish: a standard-tier reviewer plus a deep-tier reviewer running in
parallel, then a quality-gate run before and after. `AGENTS.md` section 18
requires it for a **non-trivial** change — spans more than one layer, adds
a new entity/provider/repository/Cubit/screen/route, or touches error
handling or architecture boundaries. For something smaller — a docs-only
edit, a single-line fix, a copy/localization tweak with no logic change —
running `fvm dart run tool/quality_gate.dart` yourself (or asking
`quality-guardian` to) is enough; spinning up both reviewers for a typo fix
is wasted tokens for no additional signal. When in doubt, the gate is
mandatory either way — the two-reviewer protocol is the part that scales
with how much the change actually touches.

## Example 1 — "Add a Drift-backed Tasks feature with a list, detail and create screen"

This touches every layer, so it's a job for the full pipeline, not a single
agent:

1. **`architect`** (deep tier, read-only) is triggered first because the
   request spans more than one layer. It reads root `AGENTS.md` and every
   `packages/*/AGENTS.md` on the path it'll touch, then produces a concrete
   plan in the order `AGENTS.md` section 7 mandates: `Task` entity →
   `TaskDataProvider` interface → `TaskRepository` → Drift implementation →
   `lib/bootstrap.dart` wiring → `TaskListCubit`/`TaskDetailCubit` →
   screens → tests for each. It flags explicitly that
   `.agents/skills/choose-data-stack/SKILL.md` needs to run first, since
   `packages/data` ships with no persistence package installed — Drift
   isn't there yet.
2. Because a data stack still needs choosing, **`choose-data-stack`** runs
   next (typically the developer confirms "yes, Drift" at this point,
   since it's a one-time, whole-app decision, not something the architect
   decides unilaterally). It adds the Drift dependency, a
   Drift-specific `FailureMapper`, a provider skeleton, and an in-memory
   test harness.
3. **`feature-implementer`** (standard tier, write access) takes the
   architect's plan and implements it one layer at a time — entity, then
   interface, then repository, then the Drift provider (wrapped in
   `guard`/`guardStream`, per `AGENTS.md` section 9), then the composition
   root wiring, then the Cubits, then the screens (following the
   Screen/View split from `AGENTS.md` section 8, imitating
   `features/home/presentation/home_screen.dart` for the presentation
   half). It writes each piece's test in the same step that introduces it,
   loading `new-feature`, `domain-modeling`, `data-provider`,
   `state-management`, `ui-screen`, `routing`, `localization`, `testing`
   and `error-handling` as it goes — these are the skills listed in its
   `ai/agents/feature-implementer.yaml` `skills:` field. Every new-facing
   string goes into `packages/ui/lib/l10n/app_en.arb`/`app_es.arb` before
   the screen is considered done.
4. Before handing back, `feature-implementer` runs
   `fvm dart run tool/quality_gate.dart` itself — it does not hand back code
   it hasn't verified compiles, analyzes clean, and passes tests.
5. Once the feature is "done" in the developer's eyes, the **`code-review`**
   protocol (see Example 2) is the expected next step before merging.

If the request had been UI-only — "build me a settings screen from this
Figma frame" — it would go straight to **`ui-implementer`** instead of the
full pipeline: it implements pixel-perfect UI from the Figma MCP server
(optional, see `ai/mcp.yaml`) but explicitly does *not* wire business logic,
leaving every callback as a documented `// TODO(logic): ...` stub and
ending its report with a "Logic Stubs — Action Required" table for
`feature-implementer` or the developer to fill in next.

## Example 2 — "Review my last change"

This is the `code-review` skill/workflow, which orchestrates four of the
eight subagents (`ai/workflows/review.md` is the single source of truth for
this protocol — the Antigravity workflow is generated from it, and the
Claude/Codex/OpenCode skill is a hand-written wrapper that points at it
rather than duplicating it, so the protocol itself is still edited in
exactly one place; Pi has no subagents to orchestrate, so this protocol
doesn't apply there — see `ai/README.md`'s harness-support
table):

1. **Pre-gate**: `quality-guardian` runs first (`fvm dart run
   tool/quality_gate.dart`, then a structured report). If it comes back
   REJECTED, the process stops right there — there's no point running two
   expensive reviews against code that doesn't even `dart format`/`flutter
   analyze` clean yet.
2. **Parallel, blind review**: `reviewer` (standard tier) and
   `senior-reviewer` (deep tier) are dispatched on the *same* diff, *at the
   same time*, and neither is shown the other's output. This is
   deliberate, not an implementation shortcut: a second reviewer that sees
   the first reviewer's findings tends to silently defer to them instead of
   independently re-deriving whether something is actually wrong. Running
   them blind means two genuinely independent passes, on two different
   model tiers, over the same code. Both check correctness, architecture
   boundaries (a stray `data` import in `ui`, `get_it`, a repository
   interface — everything `AGENTS.md` section 20 forbids), error handling,
   test quality, and i18n — `senior-reviewer` additionally goes deeper on
   architectural fit and subtle state-management bugs (a missing
   `isClosed` check, an uncancelled stream subscription, a `mounted` check
   after an `await`).
3. **Synthesis** (done by the orchestrating agent itself, not a further
   subagent): the two findings lists are merged. A finding both reviewers
   raised independently is marked *confirmed by both* and kept at its
   highest severity; a finding only one raised is kept too, marked
   *single-source* — a weaker signal, not a discarded one. The result is a
   verdict: **PASS**, **PASS_WITH_NITS**, or **BLOCK** (any blocking/major
   finding).
4. **You decide**: the synthesized findings are presented, most severe
   first, and you choose which to fix. Nothing is auto-applied.
5. **Fix**: `review-fixer` is dispatched with *exactly* the findings you
   confirmed — nothing else. It won't fix an issue you didn't confirm even
   if it notices one, and it won't refactor beyond what a fix strictly
   requires.
6. **Final gate**: `quality-guardian` runs again to confirm the fixes
   didn't regress anything.

## Example 3 — "Set up Firebase as the data stack"

This is a narrower, single-skill job: `.agents/skills/choose-data-stack/SKILL.md`
adds the Firebase packages to `packages/data/pubspec.yaml`, generates a
Firebase-specific `FailureMapper` (translating `FirebaseException` into the
right `DomainFailure` subtype via `guard`/`guardStream`), a data-source
wrapper for the Firebase client, and a test harness appropriate to Firebase
(typically a mocked client, since there's no lightweight in-memory Firebase
equivalent). No architect plan is needed here — it's a single, well-defined
operation, not a multi-layer feature — but a subsequent feature that uses
Firebase (Example 1's shape, with Firebase instead of Drift) would follow
the same pipeline afterward.

## A practical note on the review protocol

The two reviewers running "blind" means exactly what it says: if you're
orchestrating this by hand rather than through the packaged skill, dispatch
`reviewer` and `senior-reviewer` in the same turn, and do not paste one's
output into the other's prompt. And regardless of how confident either
reviewer sounds, no fix ever lands without you explicitly confirming it
first — `review-fixer` is built to refuse (and report separately) any
finding that wasn't on the confirmed list, not to use its own judgment
about which findings look real.
