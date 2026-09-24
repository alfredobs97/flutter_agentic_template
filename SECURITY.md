# Security Policy

## Supported versions

This template tracks a single moving line of development: `main`. There are
no maintained release branches — apply security fixes by pulling the latest
`main`, or by re-generating your app from an updated copy of the template if
you have already diverged from it.

## Reporting a vulnerability

Please **do not** open a public GitHub issue for a security vulnerability.

Instead, use GitHub's [private vulnerability reporting](https://github.com/alfredobs97/flutter_agentic_template/security/advisories/new)
for this repository (Security tab → "Report a vulnerability"). This opens a
private advisory visible only to the maintainer until a fix is available.

Include, where relevant:

- A description of the vulnerability and its potential impact.
- Steps to reproduce it (a minimal repro against a fresh clone of the
  template is ideal).
- The affected file(s)/commit.

You can expect an initial response within a few days. Once a fix is merged,
the advisory is published and credited to the reporter, unless you ask to
stay anonymous.

## Scope

This is an application template, not a hosted service — most "vulnerabilities"
here take the form of an insecure default or pattern that a generated app
would inherit (for example, a data-provider mapper that swallows an error
instead of surfacing a `DomainFailure`, or a CI/config file that would
encourage committing a secret). Please report those the same way as a
traditional vulnerability.
