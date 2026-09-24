---
name: domain-modeling
description: Deep dive on designing a domain entity in packages/domain — Equatable value equality, the hand-written copyWith sentinel pattern for nullable fields, variant inheritance for entities tied to another entity, the sortedX getter convention, and where business-rule methods belong; use whenever designing or reviewing an entity or value object.
---
# Domain modeling: designing an entity

An entity lives in `packages/domain/lib/src/entities/`. It is pure Dart —
no `flutter`, no `data`, no storage/network package (`packages/domain/AGENTS.md`
and AGENTS.md section 2) — and it is the one place business rules that
belong to the *thing itself* (not to a particular screen or use case) should
live. This skill covers entity design in isolation; for the full
entity-to-screen sequence see `.agents/skills/new-feature/SKILL.md`.

Every example below models a generic `Task`/`Project` domain. Do not copy
naming from an unrelated app's domain model — mirror the *shape*
demonstrated here and in
`packages/domain/lib/src/entities/feature_flag.dart`, not any specific
example's field names.

## 1. Base shape: `Equatable`, immutable, no generated code

```dart
import 'package:equatable/equatable.dart';

final class Task extends Equatable {
  const Task({
    required this.id,
    required this.title,
    required this.isDone,
    this.dueDate,
  });

  final String id;
  final String title;
  final bool isDone;
  final DateTime? dueDate;

  @override
  List<Object?> get props => [id, title, isDone, dueDate];
}
```

- `final class`, not `class` — closes the entity to further subclassing from
  outside `packages/domain` unless you're deliberately modeling a variant
  (section 3 below), in which case the base becomes non-`final` on purpose.
- Every constructor field is `final`; there are no setters. A "change" is
  always a new instance via `copyWith`.
- `props` lists every field that participates in equality — forgetting one
  here is the most common way two logically-different entities compare as
  equal in a test or a `BlocBuilder` rebuild check.
- No `freezed`, no `json_serializable`. `copyWith` is hand-written (see
  `entities.dart`'s doc comment) so the sentinel pattern below is expressible
  without a code-generation dependency `domain` isn't allowed to have.

## 2. `copyWith` and the `_unset` sentinel for explicitly-nullable fields

A naive `copyWith` cannot distinguish "leave this field alone" from
"explicitly set it to `null`" when the parameter itself is nullable — both
cases look like passing `null`. The fix is a private sentinel value that is
never a legitimate argument:

```dart
const _unset = Object();

final class Task extends Equatable {
  const Task({
    required this.id,
    required this.title,
    required this.isDone,
    this.dueDate,
  });

  final String id;
  final String title;
  final bool isDone;
  final DateTime? dueDate;

  Task copyWith({String? title, bool? isDone, Object? dueDate = _unset}) => Task(
    id: id,
    title: title ?? this.title,
    isDone: isDone ?? this.isDone,
    dueDate: identical(dueDate, _unset) ? this.dueDate : dueDate as DateTime?,
  );

  @override
  List<Object?> get props => [id, title, isDone, dueDate];
}
```

Why each part matters:

- `dueDate`'s parameter type is `Object?`, not `DateTime?` — this is what
  lets it accept the sentinel (`_unset`, itself an `Object`) as its default
  value. A `DateTime?` parameter could not default to an `Object`.
- The check is `identical(dueDate, _unset)`, not `dueDate == _unset` —
  `identical` is the correct equality for a marker object; `==` would work
  here too since `Object` doesn't override it, but `identical` documents the
  intent unambiguously.
- Three call sites, three distinct outcomes:
  ```dart
  task.copyWith();                       // dueDate unchanged
  task.copyWith(dueDate: DateTime(2026)); // dueDate set to 2026-01-01
  task.copyWith(dueDate: null);           // dueDate explicitly cleared
  ```
- Do **not** apply this pattern to a non-nullable field (`title`, `isDone`
  above) — a plain `T?` parameter with `?? this.field` is sufficient there,
  and adding the sentinel unconditionally to every field is needless
  ceremony that obscures which fields actually need it.
- `id` is deliberately not a `copyWith` parameter at all — identity doesn't
  change across a `copyWith` call; if code needs a different id, it should
  construct a new `Task(...)`, not `copyWith` one.

## 3. Variant inheritance: a non-nullable reference on a subclass, not a nullable field on the base

When an entity is *sometimes* tied to another entity, resist adding a
nullable foreign-key field to the base class:

```dart
// AVOID — every caller has to null-check projectId even when the domain
// rule is "an assigned task always has a project".
final class Task extends Equatable {
  const Task({required this.id, required this.title, this.projectId});
  final String? projectId;
}
```

Model it as a subclass with the reference made non-nullable instead:

```dart
class Task extends Equatable {
  const Task({required this.id, required this.title, required this.isDone});

  final String id;
  final String title;
  final bool isDone;

  @override
  List<Object?> get props => [id, title, isDone];
}

/// A [Task] that has been assigned to a project. [projectId] is guaranteed
/// non-null — there is no such thing as an [AssignedTask] without one.
final class AssignedTask extends Task {
  const AssignedTask({
    required super.id,
    required super.title,
    required super.isDone,
    required this.projectId,
  });

  final String projectId;

  @override
  List<Object?> get props => [...super.props, projectId];
}
```

The base class (`Task` here) must be non-`final` (or `sealed`/`abstract`)
for this to compile — only make it non-`final` when you actually intend a
subclass; a plain value entity with no variant stays `final class` as in
section 1.

Callers narrow with a type check instead of a null check:

```dart
// Before (nullable field): if (task.projectId != null) { ... task.projectId! ... }
// After (variant):
if (task is AssignedTask) {
  scheduleReminder(task.projectId); // no `!`, no nullability to forget
}
```

This scales to more than one variant dimension — e.g. `RecurringTask extends
Task` with a non-nullable `frequency` — each modeling one "this kind of task
always has this extra, mandatory piece of data" rule as a type, not a
`null`-checked optional field shared by every kind.

## 4. The `sortedX` getter convention

Never assume a `List` field is already in a meaningful order — a data
provider may return rows in insertion order, primary-key order, or whatever
order its underlying query happened to produce. If a field's order matters
to a caller, expose a getter that sorts on demand instead of promising (or
silently relying on) the backing field being pre-sorted:

```dart
final class Project extends Equatable {
  const Project({required this.id, required this.name, required this.tasks});

  final String id;
  final String name;
  final List<Task> tasks;

  /// Tasks in due-date order, undated tasks last. Use this instead of
  /// [tasks] directly whenever display or processing order matters — the
  /// backing field's order is not guaranteed.
  List<Task> get sortedTasks {
    final sorted = [...tasks];
    sorted.sort((a, b) {
      if (a.dueDate == null && b.dueDate == null) return 0;
      if (a.dueDate == null) return 1;
      if (b.dueDate == null) return -1;
      return a.dueDate!.compareTo(b.dueDate!);
    });
    return sorted;
  }

  @override
  List<Object?> get props => [id, name, tasks];
}
```

`props` still lists the *unsorted* `tasks` — a getter is derived, not stored
state, so it must not appear in `props` (it would just recompute the same
comparison `Equatable` already does structurally on the list).

## 5. Where business-rule methods belong

A rule that only needs the entity's own fields to evaluate belongs on the
entity as a method or getter — not duplicated inside every Cubit that needs
the answer, and not left for the UI layer to compute from raw fields:

```dart
final class Task extends Equatable {
  const Task({
    required this.id,
    required this.title,
    required this.isDone,
    this.dueDate,
  });

  final String id;
  final String title;
  final bool isDone;
  final DateTime? dueDate;

  /// True once [dueDate] has passed and the task is still open. A screen
  /// renders this as an overdue badge; a Cubit filters on it to build an
  /// "overdue" list — both read this getter instead of re-deriving the
  /// `dueDate.isBefore(now) && !isDone` check themselves.
  bool isOverdue({DateTime? now}) {
    final reference = now ?? DateTime.now();
    return dueDate != null && !isDone && dueDate!.isBefore(reference);
  }

  @override
  List<Object?> get props => [id, title, isDone, dueDate];
}
```

Guidelines for the boundary:

- If the rule needs only `this`'s fields (plus maybe a passed-in "current
  time"/"current user" for testability, as `now` is above), it's an entity
  method.
- If the rule needs to *combine data from two different entities* that
  aren't in a parent/child relationship (e.g. "is this task visible to this
  user"), it belongs on the repository instead
  (`packages/domain/lib/src/repositories/`) — repositories hold the
  orchestration a use case would hold elsewhere (`packages/domain/AGENTS.md`).
- If the rule needs `BuildContext`, a `DateTime.now()` with no way to inject
  a fixed clock for a test, or any Flutter/UI concept, it does not belong on
  the entity — keep the entity method pure and deterministic and let the
  Cubit or widget supply the "now"/"context" it evaluates against.
- Never write the same conditional (`dueDate != null && !isDone && ...`)
  inline in more than one Cubit or widget — that duplication is the signal
  the rule was supposed to live on the entity.

## Checklist

- [ ] Entity `extends Equatable`; `props` lists every field, including ones
      added later.
- [ ] `copyWith` is hand-written; the sentinel pattern (`_unset`) is used
      only for fields that must be explicitly clearable to `null` — not
      applied to non-nullable fields.
- [ ] A field tied to another entity that is *sometimes* absent is modeled
      as a subclass with a non-nullable reference, not a nullable field on
      the base.
- [ ] A `List` field whose order matters has a `sortedX` getter; the backing
      field itself is never assumed sorted.
- [ ] A business rule expressible from the entity's own fields is a method
      on the entity, not duplicated across Cubits.
- [ ] No `flutter`, `dart:io`, or storage/network import — `tool/check_architecture.dart`
      rejects it (AGENTS.md section 2).
- [ ] Exported from `entities.dart`, and `entities.dart` is exported from
      `packages/domain/lib/domain.dart`.
- [ ] A test exists under `packages/domain/test/entities/` covering
      `copyWith`'s clear-vs-leave-alone behavior for every nullable field and
      any entity method added (see AGENTS.md section 6 and
      `.agents/skills/testing/SKILL.md`).

## Common mistakes

- Forgetting a field in `props` — two entities that differ only in that
  field compare as equal, which silently breaks `BlocBuilder`'s rebuild
  check and any test asserting inequality.
- Giving every nullable field the `_unset` sentinel treatment "for
  consistency" even when nothing ever needs to clear it back to `null` —
  adds a parameter type that isn't `T?` for no behavioral benefit.
- Adding a nullable foreign-key field to a base entity instead of a variant
  subclass, then scattering `if (x.fooId != null)` null-checks across
  Cubits and widgets instead of a single `is AssignedTask` check.
- Sorting a list field in its constructor and calling that "the sortedX
  convention" — the getter must exist and do the sort, precisely because
  the backing field's order is not a guarantee any caller should rely on.
- Putting a rule that needs `BuildContext`, `context.l10n`, or an
  un-injectable `DateTime.now()` directly on the entity, making it
  impossible to unit test with `package:test` alone (`packages/domain/AGENTS.md`
  → "Testing": pure `package:test`, no Flutter dependency).
