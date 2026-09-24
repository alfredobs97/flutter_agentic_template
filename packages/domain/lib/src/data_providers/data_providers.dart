/// Barrel for `data_providers/` — currently empty by design.
///
/// A data provider is an `abstract interface class` that declares the
/// operations a repository needs (`getAll`, `watchAll`, `save`, `delete`,
/// ...) **in terms of entities**, with no mention of SQL, HTTP, or any
/// specific package. It lives in `domain` even though it has zero logic,
/// because `domain` is the layer allowed to define what it needs from the
/// outside world — `data` then `implements` it.
///
/// Example (do not uncomment — this is illustrative; see
/// `.agents/skills/data-provider/SKILL.md` for the generator):
/// ```dart
/// abstract interface class TaskDataProvider {
///   Future<List<Task>> getAllTasks();
///   Stream<List<Task>> watchAllTasks();
///   Future<Task?> getTaskById(String id);
///   Future<void> saveTask(Task task);
///   Future<void> deleteTask(String id);
/// }
/// ```
///
/// This folder is empty because the template ships no sample feature (see
/// README.md → "Why an empty skeleton"). The first time you run
/// `.agents/skills/new-feature/SKILL.md`, its generated interface file gets
/// exported here.
library;
