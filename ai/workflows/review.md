---
name: code-review
description: >
  Run the parallel, blind code-review protocol on the current diff (or a
  named PR/branch/path), then apply only the findings the user confirms.
---

# Code review protocol

This is the orchestration this template's review agents (`reviewer`,
`senior-reviewer`, `review-fixer`, `quality-guardian`) plug into. It exists
as one written protocol, not duplicated prose per tool, so a change to the
process only has to be made once — see `ai/README.md`.

## Why blind and parallel, not sequential

A single reviewer anchors on whatever it notices first. Two reviewers that
see each other's output converge — the second one silently defers to the
first instead of independently re-deriving whether something's actually
wrong. Running them **in parallel, each blind to the other's findings**,
means two independent passes over the same diff, on two different model
tiers (`reviewer` is `standard`, `senior-reviewer` is `deep` — see
`ai/agents/*.yaml`), and the synthesis step is what benefits from that
independence: an issue both flag independently is almost certainly real; an
issue only one flags still gets surfaced, but at lower confidence.

## Steps

1. **Pre-gate**: run `quality-guardian`. If it reports REJECTED, stop here
   and surface its report — there's no point running two expensive reviews
   against code that doesn't even pass `dart format`/`flutter analyze` yet.
2. **Parallel blind review**: dispatch `reviewer` and `senior-reviewer` on
   the same diff, at the same time, neither given the other's output.
   Each returns findings in this shape:
   ```
   {
     "id": "<short slug>",
     "file": "path/to/file.dart",
     "line": 42,
     "severity": "blocking | major | minor | nit",
     "summary": "one sentence",
     "failure_scenario": "concrete input/state -> wrong output or crash",
     "rule_ref": "AGENTS.md section N, or a specific existing pattern",
     "fix_hint": "one sentence, not a diff"
   }
   ```
3. **Synthesis** (the orchestrator, not a subagent): merge both findings
   lists.
   - A finding both reviewers raised independently (same file, overlapping
     line range, same underlying issue) is marked **confirmed by both** and
     kept at its highest reported severity.
   - A finding only one reviewer raised is kept, marked **single-source**,
     at its reported severity.
   - Drop a finding only if it's factually wrong (cites a rule the code
     doesn't actually violate) — don't drop a finding just because only one
     reviewer caught it; that's a valid signal, just a weaker one.
   - Produce a verdict:
     - **PASS** — no blocking or major findings.
     - **PASS_WITH_NITS** — only minor/nit findings.
     - **BLOCK** — any blocking or major finding.
4. **User decides**: present the synthesized findings (most severe first)
   and ask which to fix. Never auto-apply a fix without this step.
5. **Fix**: dispatch `review-fixer` with exactly the confirmed findings —
   nothing else.
6. **Final gate**: run `quality-guardian` again to confirm the fixes didn't
   regress anything, and that everything it checks is still green.

## Invoking it

- Claude Code / Codex / OpenCode: the `code-review` skill
  (`.agents/skills/code-review/SKILL.md`) walks through these steps
  interactively. OpenCode dispatches the generated `.opencode/agents/`
  (`reviewer`, `senior-reviewer`, `review-fixer`, `quality-guardian`) for
  steps 1, 2 and 5.
- Antigravity: the `code-review` workflow (`.agents/workflows/code-review.md`)
  does the same.
- **Pi has no subagents, so this protocol does not run there** — it is out
  of scope for this template (a deliberate choice, not a gap to fill; see
  `ai/README.md`'s harness-support table). Pi loads `.agents/skills/`
  natively, which includes this `code-review` skill file, so a Pi session
  that reads it will be told to dispatch subagents it cannot dispatch —
  don't be misled by the skill being visible there.

The Antigravity workflow is generated from this file; the skill is a
hand-written wrapper that points at it instead of duplicating it — see
`ai/README.md`'s Layout section.
