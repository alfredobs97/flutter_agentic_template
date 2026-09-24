---
name: choose-data-stack
description: Adds the first storage or network package to packages/data (Drift, Hive/Isar, Dio, or Firebase/Supabase) together with a FailureMapper, a guard-wrapped provider skeleton and a test harness; run this once, before writing the first data provider, when packages/data/pubspec.yaml has no persistence/network dependency yet.
---
# Choose a data stack

`packages/data` ships with **zero** storage/network dependencies — only
`domain` and `uuid` (see `packages/data/pubspec.yaml`). AGENTS.md section 7
and `packages/data/AGENTS.md` both require this skill to run before the
first data-provider implementation is written. `lib/src/data_providers/`,
`lib/src/data_sources/` and `lib/src/models/` in `packages/data` exist and
are ready to receive files but are currently empty.

## 1. Pick a stack

Ask the user which stack fits the app, or infer it from context (an
offline-first app with relational data → Drift; a simple key-value cache →
Hive/Isar; a thin REST client → Dio; an app that wants managed auth/sync →
Firebase/Supabase). Multiple stacks can coexist later (e.g. Drift for local
cache + Dio for sync) — add each one's dependencies only when a provider
actually needs it.

Every subsection below follows the same shape: (a) the pubspec dependencies
to add, (b) a `FailureMapper` translating that package's real exception types
into the five `DomainFailure` subtypes (`packages/domain/lib/src/failures/domain_failure.dart`:
`UnexpectedFailure`, `NotFoundFailure`, `ValidationFailure`,
`ConnectivityFailure`, `UnauthorizedFailure`), (c) a provider skeleton
wrapping `guard`/`guardStream`, (d) a test-harness pattern. Every example
uses a generic `Note` entity (`id`, `title`, `body`, `updatedAt`) — swap it
for your real entity, don't copy the shape verbatim.

After adding a stack, run `fvm flutter pub get` from the repo root, then
proceed with `.agents/skills/data-provider/SKILL.md` and
`.agents/skills/new-feature/SKILL.md` for the full generator.

---

## Option A — Drift (SQLite, offline-first, relational)

### a. Dependencies

`packages/data/pubspec.yaml`:
```yaml
dependencies:
  domain:
    path: ../domain
  drift: ^2.24.0
  path_provider: ^2.1.5
  sqlite3_flutter_libs: ^0.5.28
  uuid: ^4.5.1

dev_dependencies:
  build_runner: ^2.4.15
  drift_dev: ^2.24.0
  flutter_test:
    sdk: flutter
  very_good_analysis: ^10.0.0
```

Also add `flutter_test`'s transitive Flutter dependency by keeping this
package's `resolution: workspace` — Drift's generated code needs
`dart:ffi`/platform bindings that only resolve inside the Flutter SDK
constraint already declared in `environment: sdk:`.

### b. FailureMapper

```dart
// packages/data/lib/src/data_sources/drift_failure_mapper.dart
import 'package:domain/domain.dart';
import 'package:drift/drift.dart';

DomainFailure mapDriftError(Object error) => switch (error) {
  SqliteException(extendedResultCode: final code) when code == 787 =>
    // SQLITE_CONSTRAINT_FOREIGNKEY — a referenced row doesn't exist.
    ValidationFailure(error),
  SqliteException(extendedResultCode: final code) when code == 2067 =>
    // SQLITE_CONSTRAINT_UNIQUE.
    ValidationFailure(error),
  InvalidDataException() => ValidationFailure(error),
  _ => UnexpectedFailure(error),
};
```

Drift has no built-in "not found" exception — a missing row is a `null`
return from `getSingleOrNull()`, which the provider maps to a `NotFoundFailure`
explicitly rather than through the mapper (see the skeleton below).

### c. Provider skeleton

```dart
// packages/data/lib/src/data_sources/app_database.dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [Notes])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static LazyDatabase _openConnection() => LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    return NativeDatabase.createInBackground(File(p.join(dir.path, 'app.sqlite')));
  });
}
```

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
  Future<Note?> getNoteById(String id) => guard(() async {
    final row = await (_db.select(_db.notes)..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _mapToEntity(row);
  }, mapper: mapDriftError);

  @override
  Stream<List<Note>> watchAllNotes() =>
      guardStream(() => _db.select(_db.notes).watch().map((rows) => rows.map(_mapToEntity).toList()),
          mapper: mapDriftError);

  @override
  Future<void> saveNote(Note note) => guard(
    () => _db.into(_db.notes).insertOnConflictUpdate(_mapFromEntity(note)),
    mapper: mapDriftError,
  );

  @override
  Future<void> deleteNote(String id) =>
      guard(() => (_db.delete(_db.notes)..where((t) => t.id.equals(id))).go(), mapper: mapDriftError);

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

Every FK column and every column used in a `WHERE`/`ORDER BY` needs a Drift
index — see `.agents/skills/data-provider/SKILL.md` for the indexing pattern
and the `.watch()`-joins-not-`asyncMap()` rule.

### d. Test harness

```dart
// packages/data/test/data_providers/drift_note_data_provider_test.dart
import 'package:data/data.dart';
import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftNoteDataProvider provider;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    provider = DriftNoteDataProvider(db);
  });

  tearDown(() => db.close());

  test('saveNote then getNoteById round-trips the entity', () async {
    final note = Note(id: '1', title: 'Title', body: 'Body', updatedAt: DateTime(2026));

    await provider.saveNote(note);

    expect(await provider.getNoteById('1'), note);
  });
}
```

`NativeDatabase.memory()` gives every test an isolated, ephemeral database —
prefer this over mocking Drift (`packages/data/AGENTS.md` → "Testing").

---

## Option B — Hive or Isar (NoSQL local storage)

### a. Dependencies (Isar shown; Hive is analogous with `hive`/`hive_flutter`)

```yaml
dependencies:
  domain:
    path: ../domain
  isar: ^3.1.8
  isar_flutter_libs: ^3.1.8
  path_provider: ^2.1.5
  uuid: ^4.5.1

dev_dependencies:
  build_runner: ^2.4.15
  flutter_test:
    sdk: flutter
  isar_generator: ^3.1.8
  very_good_analysis: ^10.0.0
```

### b. FailureMapper

```dart
// packages/data/lib/src/data_sources/isar_failure_mapper.dart
import 'package:domain/domain.dart';
import 'package:isar/isar.dart';

DomainFailure mapIsarError(Object error) => switch (error) {
  IsarError(message: final message) when message.contains('unique') => ValidationFailure(error),
  IsarNotReadyError() => UnexpectedFailure(error),
  _ => UnexpectedFailure(error),
};
```

Isar/Hive, like Drift, represent "not found" as a `null` read rather than a
thrown exception — map it explicitly in the provider, not the mapper.

### c. Provider skeleton

```dart
// packages/data/lib/src/data_providers/isar_note_data_provider.dart
import 'package:domain/domain.dart';
import 'package:isar/isar.dart';

import '../data_sources/isar_failure_mapper.dart';
import '../data_sources/note_isar_model.dart';
import '../guards/failure_guard.dart';

final class IsarNoteDataProvider implements NoteDataProvider {
  IsarNoteDataProvider(this._isar);

  final Isar _isar;

  @override
  Future<Note?> getNoteById(String id) => guard(() async {
    final row = await _isar.noteIsarModels.filter().idEqualTo(id).findFirst();
    return row?.toEntity();
  }, mapper: mapIsarError);

  @override
  Stream<List<Note>> watchAllNotes() => guardStream(
    () => _isar.noteIsarModels.where().watch(fireImmediately: true).map(
      (rows) => rows.map((row) => row.toEntity()).toList(),
    ),
    mapper: mapIsarError,
  );

  @override
  Future<void> saveNote(Note note) =>
      guard(() => _isar.writeTxn(() => _isar.noteIsarModels.put(NoteIsarModel.fromEntity(note))),
          mapper: mapIsarError);

  @override
  Future<void> deleteNote(String id) => guard(
    () => _isar.writeTxn(() => _isar.noteIsarModels.filter().idEqualTo(id).deleteFirst()),
    mapper: mapIsarError,
  );
}
```

Keep the `NoteIsarModel` (the `@collection` annotated class) plus its
`toEntity()`/`fromEntity()` conversions in `lib/src/data_sources/`, private
to this provider file's imports — not a shared cross-feature "mapper layer"
(`packages/data/AGENTS.md` → "Models/mappers").

### d. Test harness

```dart
// packages/data/test/data_providers/isar_note_data_provider_test.dart
import 'package:data/data.dart';
import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  late Isar isar;
  late IsarNoteDataProvider provider;

  setUp(() async {
    isar = await Isar.open([NoteIsarModelSchema], directory: '', inspector: false);
    provider = IsarNoteDataProvider(isar);
  });

  tearDown(() => isar.close(deleteFromDisk: true));

  test('saveNote then getNoteById round-trips the entity', () async {
    final note = Note(id: '1', title: 'Title', body: 'Body', updatedAt: DateTime(2026));

    await provider.saveNote(note);

    expect(await provider.getNoteById('1'), note);
  });
}
```

An empty `directory: ''` opens an in-memory-equivalent, disposable instance
per test — the same "real, ephemeral instance over mocking" preference as
Drift's `NativeDatabase.memory()`.

---

## Option C — Dio (REST)

### a. Dependencies

```yaml
dependencies:
  dio: ^5.9.0
  domain:
    path: ../domain
  uuid: ^4.5.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.5
  very_good_analysis: ^10.0.0
```

### b. FailureMapper

```dart
// packages/data/lib/src/data_sources/dio_failure_mapper.dart
import 'package:dio/dio.dart';
import 'package:domain/domain.dart';

DomainFailure mapDioError(Object error) {
  if (error is! DioException) return UnexpectedFailure(error);

  return switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.connectionError => ConnectivityFailure(error),
    DioExceptionType.badResponse => switch (error.response?.statusCode) {
      404 => NotFoundFailure(error),
      401 || 403 => UnauthorizedFailure(error),
      400 || 422 => ValidationFailure(error),
      _ => UnexpectedFailure(error),
    },
    _ => UnexpectedFailure(error),
  };
}
```

### c. Provider skeleton

```dart
// packages/data/lib/src/data_providers/dio_note_data_provider.dart
import 'package:dio/dio.dart';
import 'package:domain/domain.dart';

import '../data_sources/dio_failure_mapper.dart';
import '../guards/failure_guard.dart';

final class DioNoteDataProvider implements NoteDataProvider {
  DioNoteDataProvider(this._client);

  final Dio _client;

  @override
  Future<Note?> getNoteById(String id) => guard(() async {
    try {
      final response = await _client.get<Map<String, dynamic>>('/notes/$id');
      return _mapToEntity(response.data!);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }, mapper: mapDioError);

  @override
  Future<List<Note>> getAllNotes() => guard(() async {
    final response = await _client.get<List<dynamic>>('/notes');
    return response.data!.cast<Map<String, dynamic>>().map(_mapToEntity).toList();
  }, mapper: mapDioError);

  @override
  Future<void> saveNote(Note note) =>
      guard(() => _client.put<void>('/notes/${note.id}', data: _mapFromEntity(note)), mapper: mapDioError);

  @override
  Future<void> deleteNote(String id) =>
      guard(() => _client.delete<void>('/notes/$id'), mapper: mapDioError);

  Note _mapToEntity(Map<String, dynamic> json) => Note(
    id: json['id'] as String,
    title: json['title'] as String,
    body: json['body'] as String,
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  Map<String, dynamic> _mapFromEntity(Note note) => {
    'id': note.id,
    'title': note.title,
    'body': note.body,
    'updatedAt': note.updatedAt.toIso8601String(),
  };
}
```

A REST-backed provider has no native `watchX()` — a data-provider interface
backed by Dio typically exposes `Future<List<Note>> getAllNotes()` instead of
`Stream<List<Note>> watchAllNotes()`; don't force a stream shape onto a stack
that doesn't support one.

### d. Test harness

```dart
// packages/data/test/data_providers/dio_note_data_provider_test.dart
import 'package:data/data.dart';
import 'package:dio/dio.dart';
import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

void main() {
  late MockDio client;
  late DioNoteDataProvider provider;

  setUp(() {
    client = MockDio();
    provider = DioNoteDataProvider(client);
  });

  test('getNoteById maps a 404 to null', () async {
    when(() => client.get<Map<String, dynamic>>('/notes/1')).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/notes/1'),
        response: Response(requestOptions: RequestOptions(path: '/notes/1'), statusCode: 404),
        type: DioExceptionType.badResponse,
      ),
    );

    expect(await provider.getNoteById('1'), isNull);
  });

  test('getNoteById wraps a connection error as ConnectivityFailure', () async {
    when(() => client.get<Map<String, dynamic>>('/notes/1')).thenThrow(
      DioException(requestOptions: RequestOptions(path: '/notes/1'), type: DioExceptionType.connectionError),
    );

    await expectLater(provider.getNoteById('1'), throwsA(isA<ConnectivityFailure>()));
  });
}
```

`mocktail` is a `dev_dependency` only — never add it to `dependencies`
(AGENTS.md section 12).

---

## Option D — Firebase / Supabase (BaaS)

### a. Dependencies (Firestore shown; Supabase follows the same shape with
`supabase_flutter`)

```yaml
dependencies:
  cloud_firestore: ^5.6.0
  domain:
    path: ../domain
  firebase_core: ^3.10.0
  uuid: ^4.5.1

dev_dependencies:
  fake_cloud_firestore: ^3.1.0
  flutter_test:
    sdk: flutter
  very_good_analysis: ^10.0.0
```

### b. FailureMapper

```dart
// packages/data/lib/src/data_sources/firestore_failure_mapper.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:domain/domain.dart';

DomainFailure mapFirestoreError(Object error) {
  if (error is! FirebaseException) return UnexpectedFailure(error);

  return switch (error.code) {
    'not-found' => NotFoundFailure(error),
    'permission-denied' || 'unauthenticated' => UnauthorizedFailure(error),
    'invalid-argument' || 'already-exists' => ValidationFailure(error),
    'unavailable' || 'deadline-exceeded' => ConnectivityFailure(error),
    _ => UnexpectedFailure(error),
  };
}
```

### c. Provider skeleton

```dart
// packages/data/lib/src/data_providers/firestore_note_data_provider.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:domain/domain.dart';

import '../data_sources/firestore_failure_mapper.dart';
import '../guards/failure_guard.dart';

final class FirestoreNoteDataProvider implements NoteDataProvider {
  FirestoreNoteDataProvider(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _notes => _firestore.collection('notes');

  @override
  Future<Note?> getNoteById(String id) => guard(() async {
    final doc = await _notes.doc(id).get();
    return doc.exists ? _mapToEntity(doc) : null;
  }, mapper: mapFirestoreError);

  @override
  Stream<List<Note>> watchAllNotes() => guardStream(
    () => _notes.orderBy('updatedAt', descending: true).snapshots().map(
      (snapshot) => snapshot.docs.map(_mapToEntity).toList(),
    ),
    mapper: mapFirestoreError,
  );

  @override
  Future<void> saveNote(Note note) =>
      guard(() => _notes.doc(note.id).set(_mapFromEntity(note)), mapper: mapFirestoreError);

  @override
  Future<void> deleteNote(String id) => guard(() => _notes.doc(id).delete(), mapper: mapFirestoreError);

  Note _mapToEntity(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Note(
      id: doc.id,
      title: data['title'] as String,
      body: data['body'] as String,
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> _mapFromEntity(Note note) => {
    'title': note.title,
    'body': note.body,
    'updatedAt': Timestamp.fromDate(note.updatedAt),
  };
}
```

### d. Test harness

```dart
// packages/data/test/data_providers/firestore_note_data_provider_test.dart
import 'package:data/data.dart';
import 'package:domain/domain.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirestoreNoteDataProvider provider;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    provider = FirestoreNoteDataProvider(firestore);
  });

  test('saveNote then getNoteById round-trips the entity', () async {
    final note = Note(id: '1', title: 'Title', body: 'Body', updatedAt: DateTime(2026));

    await provider.saveNote(note);

    expect(await provider.getNoteById('1'), note);
  });
}
```

`fake_cloud_firestore` gives an in-memory Firestore instance with the real
query semantics — prefer it over mocking `FirebaseFirestore` piece by piece.
Supabase's equivalent is a `supabase_flutter` client pointed at a disposable
local/test project, since it has no first-party in-memory fake; fall back to
`mocktail` around its `PostgrestClient` if a local Supabase instance isn't
available in CI.

---

## After adding a stack

1. `fvm flutter pub get` from the repo root.
2. If the stack needs code generation (Drift, Isar): `fvm dart run build_runner build --delete-conflicting-outputs` from `packages/data/`.
3. Continue with `.agents/skills/data-provider/SKILL.md` for the interface/implementation pair, and `.agents/skills/new-feature/SKILL.md` for the full entity-to-screen sequence.
4. `fvm dart run tool/quality_gate.dart` from the repo root before considering the change done.

## Common mistakes

- Adding a mocking package (`mocktail`) or a `fake_*` test double package to
  `dependencies` instead of `dev_dependencies` — forbidden by AGENTS.md
  section 12 regardless of layer.
- Letting a package-specific exception type (`DioException`,
  `FirebaseException`, `SqliteException`, `IsarError`) escape a provider
  method uncaught — every method body must route through `guard`/
  `guardStream`.
- Choosing `UnexpectedFailure` for every branch of a `FailureMapper` "to be
  safe" — defeats the purpose; map the cases the UI actually needs to react
  to differently (offline banner for `ConnectivityFailure`, sign-in redirect
  for `UnauthorizedFailure`, ...).
- Writing the DTO/model class directly inside the provider file's public API
  instead of keeping `_mapToEntity`/`_mapFromEntity` private — a shared
  "mapper layer" across providers is explicitly against convention (see
  `.agents/skills/data-provider/SKILL.md`).
- Forgetting `build_runner` for a codegen-based stack (Drift, Isar) and
  wondering why the generated `.g.dart` file is missing.
