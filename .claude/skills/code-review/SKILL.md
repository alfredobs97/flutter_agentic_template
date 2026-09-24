---
name: code-review
description: Runs the parallel blind code-review protocol (two independent adversarial reviewers plus a quality gate) on the current diff, then applies only user-confirmed fixes — use before declaring any non-trivial implementation task done.
---

# Code review

Runs a pre-gate quality check, then two adversarial reviewers over the
current diff **in parallel and blind to each other** — each independently
re-derives whether something is actually wrong instead of one silently
converging on what the other already flagged — followed by an orchestrator
synthesis and a final quality gate. This catches the anchoring problem a
single (or sequential) reviewer has: the first opinion aired shapes every
opinion after it, so running two reviewers who cannot see each other's
output, on two different model tiers, is what makes agreement between them
a meaningful signal rather than an echo.

**Full protocol: see `ai/workflows/review.md`.** That file is the single
source of truth for the exact steps, the findings JSON schema, the
synthesis rules, and the PASS / PASS_WITH_NITS / BLOCK verdict criteria —
read it before running this skill. This SKILL.md is a thin, tool-agnostic
wrapper around it and intentionally does not duplicate its content; if the
two ever disagree, `ai/workflows/review.md` wins and this file is stale.

## How to invoke it

1. **Pre-gate.** Dispatch `quality-guardian` first. If it reports REJECTED,
   stop and surface its report — do not run the two reviewers against code
   that does not even pass formatting/analysis yet.
2. **Parallel blind review.** Dispatch `reviewer` and `senior-reviewer` as
   **two separate subagent calls sent in the same turn/message**, on the
   same diff. This is the part most likely to be done wrong: running them
   one after the other, or handing the second reviewer the first
   reviewer's output "for context," defeats the entire purpose of blind
   review and must not happen. Neither agent sees the other's findings.
3. **Synthesis.** As the orchestrator (not a subagent), merge the two
   findings lists per the rules in `ai/workflows/review.md` — a finding
   both reviewers raised independently is confirmed-by-both at its highest
   reported severity, a single-source finding is kept at its reported
   severity, and a finding is dropped only if it is factually wrong, not
   merely because only one reviewer caught it. Derive the PASS /
   PASS_WITH_NITS / BLOCK verdict per that same document.
4. **User decides.** Present the synthesized findings, most severe first,
   and ask which ones to fix. Never auto-apply a fix — a finding without
   explicit user confirmation does not go to `review-fixer`.
5. **Fix.** Dispatch `review-fixer` with exactly the confirmed findings and
   nothing else.
6. **Final gate.** Run `quality-guardian` again to confirm the fixes did
   not regress anything and everything it checks is still green.

## When to trigger this skill

- Before declaring any non-trivial implementation task complete — this is
  part of AGENTS.md section 18's definition of done, not optional polish.
- Whenever the user explicitly asks for a review of a diff, PR, branch, or
  path.

Do not self-certify a change as done by reasoning about it yourself in
place of this protocol; the value is in the two independent adversarial
passes, not in a single agent's judgment call.

## What a good finding looks like

A finding is concrete, not vague. Compare:

- Weak: "Consider improving error handling here."
- Good: `packages/data/lib/src/data_providers/task_data_provider.dart:87`
  — a `DriftException` thrown by the `INSERT` is not caught by `guard`,
  so it reaches the repository as a raw exception instead of a
  `DomainFailure`; the Cubit that calls this will store `e.toString()` in
  its state, violating AGENTS.md section 9. Failure scenario: inserting a
  task with a duplicate id crashes the write path instead of surfacing a
  `TaskConflictFailure` the UI can render.

Every finding needs a file, a line, a concrete failure scenario (not "could
be improved"), and a rule reference — either an AGENTS.md section or an
existing pattern elsewhere in the codebase it deviates from.
