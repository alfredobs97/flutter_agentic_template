/// Barrel for `entities/`.
///
/// An entity is a pure-Dart, `Equatable` value type with no dependency on
/// `flutter`, `data`, or any storage/network package — see AGENTS.md →
/// "Dependency rule". Business rules that belong to the entity itself
/// (validation, derived getters, state transitions) live as methods here,
/// not scattered across Cubits.
///
/// Conventions (see `.agents/skills/domain-modeling/SKILL.md` for the full
/// guide and templates):
/// - `copyWith` is hand-written, not generated. For a field that must be
///   explicitly clearable to `null`, use the sentinel pattern:
///   ```dart
///   const _unset = Object();
///   Task copyWith({Object? dueDate = _unset}) => Task(
///         dueDate: identical(dueDate, _unset) ? this.dueDate : dueDate as DateTime?,
///       );
///   ```
/// - A variant tied to another entity (e.g. a `Task` assigned to a
///   `Project`) is a subclass with a non-nullable reference
///   (`AssignedTask extends Task`), not a nullable field on the base class
///   — this lets callers use `if (task is AssignedTask)` instead of null
///   checks.
/// - A list whose order matters exposes a `sortedX` getter; never assume the
///   backing field itself is sorted.
///
/// Export every entity file added under `entities/` from this barrel.
library;

export 'feature_flag.dart';
