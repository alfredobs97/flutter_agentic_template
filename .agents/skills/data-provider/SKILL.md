---
name: data-provider
description: Explains the data-provider interface/implementation pair — the abstract interface class in domain expressed only in entity terms, the guard/guardStream-wrapped implementation in data, the private mapper convention, FK indexing, and the watch()-joins-not-asyncMap gotcha; use when writing or reviewing a data provider for any layer.
---
# Writing a data provider

A data provider is split across two packages: an `abstract interface class`
in `packages/domain/lib/src/data_providers/` (the seam a repository depends
on), and a concrete implementation in `packages/data/lib/src/data_providers/`
(the only place that knows which storage/network package is actually in
use). Read `.agents/skills/choose-data-stack/SKILL.md` first if
`packages/data` has no persistence dependency yet — this skill assumes one
is already installed. The example below uses a generic `Note` entity; swap
the entity, don't copy the name.

## 1. The interface lives in `domain`, in entity terms only

```dart
// packages/domain/lib/src/data_providers/note_data_provider.dart
import '../entities/note.dart';

/// The seam `data` implements and `NoteRepository` depends on. No SQL, no
/// HTTP, no mention of Drift/Dio/Firebase/etc. — see
/// `.agents/skills/choose-data-stack/SKILL.md` for a concrete
/// implementation per stack.
abstract interface class NoteDataProvider {
  Future<List<Note>> getAllNotes();

  Stream<List<Note>> watchAllNotes();

  Future<Note?> getNoteById(String id);

  Future<void> saveNote(Note note);

  Future<void> deleteNote(String id);
}
```

- `abstract interface class`, not a plain `abstract class` — this forbids
  `data`'s implementation from `extend`ing it (only `implements`), which
  keeps the contract pure: no inherited method bodies, no shared mutable
  state smuggled in through the base class. `analysis_options.yaml` disables
  `one_member_abstracts` specifically so a single-method interface like this
  isn't flagged as unnecessary — it's the injection seam the whole
  architecture depends on.
- Method signatures name only entities (`Note`) and Dart core types
  (`String`, `Future`, `Stream`) — never a row type, a DTO, a `Response`, or
  anything the chosen stack defines. A repository or a test fake must be
  able to read this file and understand the contract without knowing Drift
  or Dio exist.
- Prefer `Future<List<T>>` when the stack has no live-query concept (a plain
  REST provider, see `choose-data-stack`'s Dio section) and add
  `Stream<List<T>> watchX()` only when the stack can actually push updates
  (Drift, Isar, Firestore). Don't fake a `Stream` with a
  `Stream.fromFuture(getAllNotes())` — that's a stream that never emits
  again after the first read, which silently breaks any `BlocBuilder`
  expecting live updates.
- Export it from `packages/domain/lib/src/data_providers/data_providers.dart`,
  which re-exports it via `domain.dart` (AGENTS.md section 13).

## 2. The implementation lives in `data`, wraps `guard`/`guardStream`

```dart
// packages/data/lib/src/data_providers/drift_note_data_provider.dart
import 'package:domain/domain.dart';

import '../data_sources/app_database.dart';
import '../data_sources/drift_failure_mapper.dart';
import '../guards/failure_guard.dart';

final class DriftNoteDataProvider implements NoteDataProvider {
  DriftNoteDataProvider(this._db);

  final AppDatabase _db;

  @override
  Future<List<Note>> getAllNotes() =>
      guard(() async => (await _db.select(_db.notes).get()).map(_mapToEntity).toList(),
          mapper: mapDriftError);

  @override
  Stream<List<Note>> watchAllNotes() => guardStream(
    () => _db.select(_db.notes).watch().map((rows) => rows.map(_mapToEntity).toList()),
    mapper: mapDriftError,
  );

  @override
  Future<Note?> getNoteById(String id) => guard(() async {
    final row = await (_db.select(_db.notes)..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _mapToEntity(row);
  }, mapper: mapDriftError);

  @override
  Future<void> saveNote(Note note) => guard(
    () => _db.into(_db.notes).insertOnConflictUpdate(_mapFromEntity(note)),
    mapper: mapDriftError,
  );

  @override
  Future<void> deleteNote(String id) =>
      guard(() => (_db.delete(_db.notes)..where((t) => t.id.equals(id))).go(), mapper: mapDriftError);

  // --- private mappers, local to this file — see section 3 below.
  Note _mapToEntity(NotesData row) =>
      Note(id: row.id, title: row.title, body: row.body, updatedAt: row.updatedAt);

  NotesCompanion _mapFromEntity(Note note) => NotesCompanion.insert(
    id: note.id,
    title: note.title,
    body: note.body,
    updatedAt: note.updatedAt,
  );
}
```

Every method body is wrapped in `guard` (for a `Future`) or `guardStream`
(for a `Stream`) from `packages/data/lib/src/guards/failure_guard.dart`,
with a `FailureMapper` specific to the wrapped package's exception types —
see `.agents/skills/choose-data-stack/SKILL.md` for a mapper per stack and
AGENTS.md section 9 for why an infrastructure exception must never reach a
repository, Cubit or widget. `guard`/`guardStream` both rethrow an existing
`DomainFailure` unchanged (see `failure_guard.dart`'s own tests,
`packages/data/test/guards/failure_guard_test.dart`), so a mapper only needs
to handle the package's *own* exception types, not `DomainFailure` itself.

## 3. Keep `_mapToEntity`/`_mapFromEntity` private and local to the provider file

`packages/data/AGENTS.md` → "Models/mappers" is explicit: if your stack
needs a DTO or generated row type distinct from the entity, the conversion
functions stay **private, inside the provider file that uses them** — not a
shared `lib/src/mappers/` directory imported by multiple providers.

```dart
// Correct: private, file-local, right next to the methods that use it.
Note _mapToEntity(NotesData row) => Note(id: row.id, title: row.title, body: row.body, updatedAt: row.updatedAt);

// AVOID: a shared "mapper layer" — two providers importing the same
// mapToEntity function couples them to each other's row/response shape for
// no benefit; each provider's mapping is specific to its own stack.
```

If two providers for the *same* entity exist (e.g. a Drift provider and a
Dio provider both implementing `NoteDataProvider`, perhaps for offline cache
vs. remote sync), each still writes and owns its own private mapper — they
are not required to look the same, and sharing one couples the two stacks'
representations together for no reason.

## 4. Foreign-key indexing (relational stores)

If the chosen stack is relational (Drift/SQLite, or any SQL-backed store),
index every foreign-key column and every column used in a `WHERE` or
`ORDER BY` clause — an unindexed `WHERE noteId = ?` on a growing table is an
easy-to-miss full table scan:

```dart
class Comments extends Table {
  TextColumn get id => text()();
  TextColumn get noteId => text().references(Notes, #id)();
  TextColumn get body => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [];
}

@DriftDatabase(tables: [Notes, Comments])
class AppDatabase extends _$AppDatabase {
  // ...

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      // noteId is a FK queried by every "comments for this note" lookup —
      // index it explicitly; Drift does not index FK columns automatically.
      await customStatement('CREATE INDEX idx_comments_note_id ON comments(note_id)');
      // createdAt drives ORDER BY in every "comments, newest first" query.
      await customStatement('CREATE INDEX idx_comments_created_at ON comments(created_at)');
    },
  );
}
```

## 5. The `.watch()`-joins-not-`asyncMap()` gotcha

A live query only tracks the tables it directly selects from. If a
`watchX()` method pulls in related data via a *separate* one-off read inside
`asyncMap`, a write to that related table will not cause the stream to
re-emit — the outer query has no idea the inner read even happened.

```dart
// WRONG — watches only `notes`. A write to `comments` (e.g. adding a
// comment) never triggers a re-emit, because Comments.watch() below runs
// once per notes-table change, not once per comments-table change.
Stream<List<NoteWithCommentCount>> watchAllNotesWrong() => (_db.select(_db.notes).watch()).asyncMap(
  (rows) async {
    final result = <NoteWithCommentCount>[];
    for (final row in rows) {
      final count = await (_db.select(_db.comments)..where((c) => c.noteId.equals(row.id))).get();
      result.add(NoteWithCommentCount(note: _mapToEntity(row), commentCount: count.length));
    }
    return result;
  },
);

// RIGHT — join the related table into the SAME watched query, so Drift
// knows this stream depends on both `notes` and `comments` and re-emits
// when either changes.
Stream<List<NoteWithCommentCount>> watchAllNotes() {
  final query = _db.select(_db.notes).join([
    leftOuterJoin(_db.comments, _db.comments.noteId.equalsExp(_db.notes.id)),
  ]);
  return query.watch().map((rows) {
    final byNote = <String, List<TypedResult>>{};
    for (final row in rows) {
      byNote.putIfAbsent(row.readTable(_db.notes).id, () => []).add(row);
    }
    return byNote.entries
        .map(
          (entry) => NoteWithCommentCount(
            note: _mapToEntity(entry.value.first.readTable(_db.notes)),
            commentCount: entry.value.where((r) => r.readTableOrNull(_db.comments) != null).length,
          ),
        )
        .toList();
  });
}
```

This generalizes beyond Drift: whatever live-query mechanism a chosen stack
offers (Isar's `.watch()`, Firestore's `.snapshots()`), a related read done
as a *second, independent* query inside the stream's transform step will not
re-fire when only the related data changes — pull related data in through
whatever join/nested-listener mechanism the stack provides for a single
subscription, or accept that the stream only reflects changes to its
directly-selected table and document that limitation on the method.

## Checklist

- [ ] Interface in `domain` is `abstract interface class`, expressed only in
      entity/core-Dart types — no SQL, HTTP, or package-specific type.
- [ ] Implementation in `data` wraps every method body in `guard`/
      `guardStream` with a stack-specific `FailureMapper`.
- [ ] `_mapToEntity`/`_mapFromEntity` are private and declared in the same
      file as the provider that uses them — not a shared mapper module.
- [ ] Every FK column and every `WHERE`/`ORDER BY` column is indexed
      (relational stores only).
- [ ] Every `watchX()` method's live query joins in whatever related data it
      returns, rather than issuing a second read inside `asyncMap`.
- [ ] Interface exported from `data_providers.dart` in `domain`;
      implementation exported from `data_providers.dart` in `data`.
- [ ] A test exists exercising the implementation against a real, ephemeral
      instance of the stack (in-memory DB, mocked HTTP client) — see
      `.agents/skills/choose-data-stack/SKILL.md`'s test-harness examples per
      stack.

## Common mistakes

- Declaring the interface with a stack-specific return type ("leaking" a
  Drift row type or a `Response` through a method signature) — defeats the
  entire point of the interface living in `domain`.
- Forgetting `mapper:` on a `guard`/`guardStream` call and silently falling
  back to `_defaultMapper` (everything becomes `UnexpectedFailure`), losing
  the ability for `ui` to react to `NotFoundFailure`/`ConnectivityFailure`/
  etc. distinctly.
- Letting a package exception type (`DriftRuntimeException`,
  `DioException`) escape through a code path that isn't wrapped in `guard`
  — e.g. a mapper function called eagerly, outside the `guard(...)` closure,
  where a thrown exception bypasses the try/catch entirely.
- Implementing `watchX()` with `asyncMap` doing a second, unrelated-table
  read (section 5) — the classic "my stream never updates when a related
  row changes" bug.
- Putting the DTO/mapper functions in a shared file imported by more than
  one provider, coupling unrelated stacks' representations together.
