---
name: localization
description: Walks through the ARB localization workflow end to end — adding a key with @key metadata (plus placeholders/plurals) to app_en.arb, translating app_es.arb, regenerating with fvm flutter gen-l10n, and consuming via context.l10n; triggers whenever a new user-facing string is being added or changed in packages/ui.
---

# Localization (ARB workflow)

`packages/ui` has Flutter localization fully configured via `gen-l10n`
(root `AGENTS.md` section 11). **No hardcoded user-facing string is
allowed anywhere in `packages/ui/`** — this is a zero-exception rule, not
a style preference, and is listed under "Forbidden patterns" in root
`AGENTS.md` section 20.

## 1. Add the key to the template ARB file

Every string starts in `packages/ui/lib/l10n/app_en.arb` — the
`template-arb-file` per `packages/ui/l10n.yaml`. Add the key, its value,
and an `@key` metadata block with a `description` explaining where/how the
string is used (this becomes the doc comment on the generated getter):

```json
{
  "@@locale": "en",
  "taskListTitle": "Tasks",
  "@taskListTitle": {
    "description": "Title of the task list screen's app bar."
  },
  "deleteTaskButtonLabel": "Delete task",
  "@deleteTaskButtonLabel": {
    "description": "Semantics/tooltip label on the icon button that deletes a task."
  }
}
```

## 2. Placeholders (parameterized strings)

A string with a runtime value declares a `placeholders` block in the
`@key` metadata, with a `type` for each placeholder:

```json
{
  "taskCreatedMessage": "\"{title}\" was added to your list.",
  "@taskCreatedMessage": {
    "description": "Snackbar shown after a task is created.",
    "placeholders": {
      "title": {
        "type": "String",
        "example": "Buy milk"
      }
    }
  }
}
```

This generates `String taskCreatedMessage(String title)` — consume it as
`context.l10n.taskCreatedMessage(task.title)`.

## 3. Plurals (ICU syntax)

A count-dependent string uses ICU `plural` syntax in the value, with a
`NUM` (or any name) placeholder typed as `int`:

```json
{
  "taskCountLabel": "{count, plural, =0{No tasks} =1{1 task} other{{count} tasks}}",
  "@taskCountLabel": {
    "description": "Summary label showing how many tasks are in the current list.",
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  }
}
```

Consume it as `context.l10n.taskCountLabel(state.tasks.length)`. `gen-l10n`
generates the plural-selection logic — never hand-roll an `if
(count == 1) ... else ...` string switch in Dart for something ICU already
expresses declaratively.

## 4. Translate `app_es.arb`

Add the matching key (same key, translated value) to
`packages/ui/lib/l10n/app_es.arb`. Non-template ARB files carry **no**
`@key` metadata blocks — only the template file (`app_en.arb`) does:

```json
{
  "@@locale": "es",
  "taskListTitle": "Tareas",
  "deleteTaskButtonLabel": "Eliminar tarea",
  "taskCreatedMessage": "\"{title}\" se añadió a tu lista.",
  "taskCountLabel": "{count, plural, =0{Sin tareas} =1{1 tarea} other{{count} tareas}}"
}
```

Placeholder names and ICU variable names must match exactly between
`app_en.arb` and `app_es.arb` — `gen-l10n` generates one function per key
shared across all locales, so a mismatched placeholder name is a codegen
error, not a silent runtime issue.

## 5. Regenerate

Run from inside `packages/ui/`:

```bash
fvm flutter gen-l10n
```

This reads `packages/ui/l10n.yaml`:

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-dir: lib/src/l10n
```

Generated output lands in `packages/ui/lib/src/l10n/` — **never hand-edit
it**; it is fully overwritten on every `gen-l10n` run. Do not add
`synthetic-package: true` to `l10n.yaml` — that option has been removed
from Flutter and will fail codegen.

## 6. Consume via `context.l10n`

Always go through the `BuildContextX` extension
(`packages/ui/lib/src/theme/context_extensions.dart`), never
`AppLocalizations.of(context)!` directly:

```dart
// Wrong
Text(AppLocalizations.of(context)!.taskListTitle);

// Right
Text(context.l10n.taskListTitle);
Text(context.l10n.taskCreatedMessage(task.title));
Text(context.l10n.taskCountLabel(state.tasks.length));
```

## Common mistakes

- Adding a string only to `app_en.arb` and forgetting `app_es.arb` —
  `gen-l10n` will fail (or fall back silently in some configurations) if a
  key is missing from a non-template locale.
- Adding `@key` metadata to `app_es.arb` (or any non-template file) —
  metadata belongs only in the template ARB file.
- Hand-rolling plural logic in Dart (`count == 1 ? '...' : '...'`) instead
  of ICU `plural` syntax in the ARB value.
- Forgetting to run `fvm flutter gen-l10n` after an ARB edit — the code
  won't see the new key until regenerated, and CI's
  `tool/quality_gate.dart` will catch a stale generated file.
- Interpolating a raw Dart string into UI at all, even for something that
  "feels" like a code value (an error code, a debug label) if it is
  user-facing — the rule in root `AGENTS.md` section 11 has no exception
  for "small" strings.
- Setting `synthetic-package: true` in `l10n.yaml`.

## Checklist

- [ ] Key + `@key` (with `description`, and `placeholders` if
      parameterized) added to `app_en.arb`.
- [ ] Matching translated key added to `app_es.arb`, with identical
      placeholder/ICU variable names.
- [ ] `fvm flutter gen-l10n` run from `packages/ui/`.
- [ ] Consumed via `context.l10n.yourKey`, not `AppLocalizations.of(context)!`.
- [ ] No hardcoded user-facing string literal remains anywhere in the
      changed `packages/ui/` code, including `Semantics`/`tooltip` labels.
