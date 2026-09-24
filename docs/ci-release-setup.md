# CI release setup (optional)

This template is **CI/CD-backend-agnostic**, the same way `packages/data`
is data-stack-agnostic: it ships no live release pipeline by default. What
it ships instead is a starting point — `.github/workflows/release.yml.example`
— an inactive, `.example`-suffixed workflow file you opt into once you've
decided how you want to actually distribute builds (Firebase App
Distribution, TestFlight, the Play Store, an internal artifact store, or
anything else).

## Activating it

The `.example` suffix keeps GitHub Actions from picking the file up as a
live workflow. To turn it on:

```
mv .github/workflows/release.yml.example .github/workflows/release.yml
```

Then commit it, review it against your actual release process (it's a
starting point, not a drop-in solution for every backend), and configure
the secrets it expects (see below) in the repository's GitHub settings
before the first tag push.

## What the workflow does, conceptually

`release.yml.example` is a **tag-driven** release workflow: pushing a tag
(rather than every commit to a branch) triggers a build-and-distribute run,
which keeps routine commits from producing a release artifact every time.
At a conceptual level, it:

- **Infers the flavor from the branch** the tag was cut from — a tag off a
  `main`/release branch produces a `prod` build
  (`--flavor prod --dart-define=FLAVOR=prod`), a tag off a
  development branch produces a `dev` build. This mirrors the same
  dev/prod split the app already enforces locally (`AGENTS.md` → "Flavors
  & environments") — CI never invents a third notion of environment.
- **Reads the pinned Flutter version from `.fvmrc`**, rather than hardcoding
  a version in the workflow file a second time — so bumping the Flutter
  version for local development (`fvm use <version>`) and CI stay in sync
  by construction instead of by remembering to update both places.
- **Needs signing/distribution secrets configured in the repository's
  GitHub settings** (Settings → Secrets and variables → Actions), never
  committed to the repo. At minimum this means whatever
  [`docs/android-release-signing.md`](android-release-signing.md)'s
  keystore values resolve to (store password, key password, key alias, and
  the keystore file itself, typically base64-encoded into a secret) plus
  whatever your chosen distribution target needs (a Firebase App
  Distribution service-account JSON, an App Store Connect API key, etc.).
  Which exact secrets are required depends on the distribution backend you
  pick — the example workflow's own comments are the authoritative list
  for the version actually checked into your repo, since it may have been
  adjusted after this document was written.

## Why this is optional and generic

The template's own philosophy — documented, working infrastructure with no
single choice forced on you — applies to releases the same way it applies
to the data stack (`packages/data`, see
[`docs/architecture.md`](architecture.md)). Baking in a specific
distribution backend would mean every app built from this template either
uses that backend or has to rip the workflow out. Instead, the example
workflow demonstrates the *shape* a tag-driven, flavor-aware, FVM-pinned
release pipeline should have, and you fill in the distribution step that
matches how you actually ship.

## Before your first real release

- Confirm [`docs/android-release-signing.md`](android-release-signing.md)
  is set up and `android/key.properties`'s values are the same ones your
  CI secrets encode.
- Run `fvm dart run tool/quality_gate.dart` locally before cutting the tag
  — CI should confirm this passes too, but there's no reason to push a tag
  you already know is red.
- Tag the release (`git tag vX.Y.Z && git push origin vX.Y.Z`, or your
  team's own tagging convention) only after the workflow has been reviewed
  and its secrets configured — an activated workflow with missing secrets
  will fail loudly at the signing/distribution step, not silently skip it.
