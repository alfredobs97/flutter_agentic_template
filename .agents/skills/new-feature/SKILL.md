---
name: new-feature
description: End-to-end generator for a whole new feature — domain entity, data-provider interface, repository, data implementation, composition-root wiring, UI Cubit and screen, plus a test at every layer — following AGENTS.md section 7's exact sequence; use when building a new feature from scratch across all three packages.
---
# Building a new feature end to end

This is the generator AGENTS.md section 7 and section 19's skill index point
to. It walks the full sequence — domain entity → data-provider interface →
repository → data implementation → composition root → UI Cubit → UI screen
— with a working example at every step, plus the test each step requires
(AGENTS.md section 6: every new entity/provider/repository/Cubit/widget/
route gets a test in the same change).

The worked example builds a `Note` feature: create, list, and delete a note.
Treat every file below as a template to adapt to your real entity — **do
not** copy the shape of an unrelated app's repository class. Mirror
`FeatureFlagRepository`
(`packages/domain/lib/src/repositories/feature_flag_repository.dart`)
instead — a plain constructor-injected class, no interface, no use-case
class (AGENTS.md section 1 and section 20 both forbid a repository
*interface* in `domain`).

Run `.agents/skills/choose-data-stack/SKILL.md` first if `packages/data` has
no persistence dependency yet. The data-layer step below assumes Drift is
installed; swap in whichever stack you chose.

## 1. Domain entity

`packages/domain/lib/src/entities/note.dart`:

```dart
import 'package:equatable/equatable.dart';

const _unset = Object();

/// A single freeform note. See `.agents/skills/domain-modeling/SKILL.md`
/// for the `copyWith`/sentinel pattern used below.
final class Note extends Equatable {
  const Note({
    required this.id,
    required this.title,
    required this.body,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String body;
  final DateTime updatedAt;

  Note copyWith({String? title, Object? body = _unset}) => Note(
    id: id,
    title: title ?? this.title,
    body: identical(body, _unset) ? this.body : body as String,
    updatedAt: updatedAt,
  );

  @override
  List<Object?> get props => [id, title, body, updatedAt];
}
```

Update the barrel: `packages/domain/lib/src/entities/entities.dart`
```dart
library;

export 'feature_flag.dart';
export 'note.dart';
```

Test: `packages/domain/test/entities/note_test.dart`
```dart
import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('Note', () {
    final note = Note(id: '1', title: 'Title', body: 'Body', updatedAt: DateTime(2026));

    test('copyWith with no arguments returns an equal copy', () {
      expect(note.copyWith(), note);
    });

    test('copyWith(title:) changes only title', () {
      expect(note.copyWith(title: 'New title').title, 'New title');
    });
  });
}
```

## 2. Domain data-provider interface

`packages/domain/lib/src/data_providers/note_data_provider.dart`:
```dart
import '../entities/note.dart';

abstract interface class NoteDataProvider {
  Future<List<Note>> getAllNotes();
  Stream<List<Note>> watchAllNotes();
  Future<Note> createNote({required String title, required String body});
  Future<void> deleteNote(String id);
}
```

`createNote` returns the created `Note` rather than taking one, because id
assignment belongs to the data provider, not its caller — this template has
no dedicated id-generation abstraction; a provider that needs one picks
whatever fits its stack (`uuid`, the database's own autoincrement/
`gen_random_uuid()`, ...) internally, since that's an infrastructure detail
(AGENTS.md section 2's dependency rule puts it squarely in `packages/data`).

Update the barrel: `packages/domain/lib/src/data_providers/data_providers.dart`
```dart
library;

export 'note_data_provider.dart';
```

See `.agents/skills/data-provider/SKILL.md` for the full rationale (why
`abstract interface class`, why entity-only signatures).

## 3. Domain repository

`packages/domain/lib/src/repositories/note_repository.dart`:
```dart
import '../data_providers/note_data_provider.dart';
import '../entities/note.dart';

/// Constructor-injected with the [NoteDataProvider] interface, mirroring
/// `FeatureFlagRepository`'s shape — a concrete class, never an interface
/// (AGENTS.md section 1). Holds the orchestration a use case would
/// otherwise hold; here, that's nothing more than delegation, but a real
/// repository combining two providers or applying a rule before persisting
/// belongs here, not in a Cubit.
final class NoteRepository {
  const NoteRepository(this._dataProvider);

  final NoteDataProvider _dataProvider;

  Future<List<Note>> getAllNotes() => _dataProvider.getAllNotes();

  Stream<List<Note>> watchAllNotes() => _dataProvider.watchAllNotes();

  Future<Note> createNote({required String title, required String body}) =>
      _dataProvider.createNote(title: title, body: body);

  Future<void> deleteNote(String id) => _dataProvider.deleteNote(id);
}
```

Update the barrel: `packages/domain/lib/src/repositories/repositories.dart`
```dart
library;

export 'feature_flag_repository.dart';
export 'note_repository.dart';
```

`packages/domain/lib/domain.dart` itself needs no edit — it already exports
the four top-level barrels (`data_providers.dart`, `entities.dart`,
`failures.dart`, `repositories.dart`), which now each carry the new file.

Test: `packages/domain/test/repositories/note_repository_test.dart`, using a
hand-written fake (`packages/domain/AGENTS.md` → "Testing": no mocking
package here, `domain/pubspec.yaml` has no `mocktail`):
```dart
import 'package:domain/domain.dart';
import 'package:test/test.dart';

final class FakeNoteDataProvider implements NoteDataProvider {
  final Map<String, Note> _notes = {};
  final _controller = StreamController<List<Note>>.broadcast();
  var _count = 0;

  @override
  Future<List<Note>> getAllNotes() async => _notes.values.toList();

  @override
  Stream<List<Note>> watchAllNotes() => _controller.stream;

  @override
  Future<Note> createNote({required String title, required String body}) async {
    final note = Note(id: 'fake-${_count++}', title: title, body: body, updatedAt: DateTime(2026));
    _notes[note.id] = note;
    _controller.add(_notes.values.toList());
    return note;
  }

  @override
  Future<void> deleteNote(String id) async {
    _notes.remove(id);
    _controller.add(_notes.values.toList());
  }
}

void main() {
  group('NoteRepository', () {
    test('createNote then getAllNotes returns the created note', () async {
      final repository = NoteRepository(FakeNoteDataProvider());

      final note = await repository.createNote(title: 'Title', body: 'Body');

      expect(await repository.getAllNotes(), [note]);
    });
  });
}
```
(add `import 'dart:async';` for `StreamController`).

## 4. Data implementation

`packages/data/lib/src/data_providers/drift_note_data_provider.dart` — see
`.agents/skills/data-provider/SKILL.md` section 2 for the full Drift
skeleton (table definition, `guard`/`guardStream` wrapping, private
`_mapToEntity`/`_mapFromEntity`). In short:

```dart
final class DriftNoteDataProvider implements NoteDataProvider {
  DriftNoteDataProvider(this._db, [Uuid? uuid]) : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Uuid _uuid;

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
  Future<Note> createNote({required String title, required String body}) => guard(() async {
    final note = Note(id: _uuid.v4(), title: title, body: body, updatedAt: DateTime.now());
    await _db.into(_db.notes).insert(_mapFromEntity(note));
    return note;
  }, mapper: mapDriftError);

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

`Uuid` comes straight from `package:uuid` (add `uuid: ^4.5.1` to
`packages/data/pubspec.yaml` if your chosen stack didn't already pull it
in) — imported and called directly here, no wrapper abstraction, because
`packages/data` is exactly where an external id-generation package is
allowed to live (AGENTS.md section 2).

Update the barrel: `packages/data/lib/src/data_providers/data_providers.dart`
```dart
library;

export 'drift_note_data_provider.dart';
```

`packages/data/lib/data.dart` needs no edit — it already exports
`src/data_providers/data_providers.dart`.

Test: `packages/data/test/data_providers/drift_note_data_provider_test.dart`
— see `.agents/skills/choose-data-stack/SKILL.md`'s Drift test-harness
example (`NativeDatabase.memory()`).

## 5. Composition root wiring

`lib/bootstrap.dart` — instantiate the database, the data provider, then the
repository, inside the existing `bootstrap()` function:

```dart
void bootstrap() {
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        _reportUncaughtError(details.exception, details.stack ?? StackTrace.current);
      };

      final featureFlagRepository = FeatureFlagRepository(
        FeatureFlags(featureFlagDefaultsFor(AppEnvironment.flavor)),
      );

      final database = AppDatabase();
      final noteDataProvider = DriftNoteDataProvider(database);
      final noteRepository = NoteRepository(noteDataProvider);

      runApp(
        App(
          router: buildAppRouter(),
          featureFlagRepository: featureFlagRepository,
          noteRepository: noteRepository,
        ),
      );
    },
    _reportUncaughtError,
  );
}
```

`lib/app.dart` — add a constructor parameter and a matching
`RepositoryProvider.value`:

```dart
class App extends StatelessWidget {
  const App({
    required this.router,
    required this.featureFlagRepository,
    required this.noteRepository,
    super.key,
  });

  final GoRouter router;
  final FeatureFlagRepository featureFlagRepository;
  final NoteRepository noteRepository;

  @override
  Widget build(BuildContext context) => MultiRepositoryProvider(
    providers: [
      RepositoryProvider<FeatureFlagRepository>.value(value: featureFlagRepository),
      RepositoryProvider<NoteRepository>.value(value: noteRepository),
    ],
    child: MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => FeatureFlagCubit(context.read<FeatureFlagRepository>())),
      ],
      child: MaterialApp.router(
        onGenerateTitle: (context) => context.l10n.appTitle,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    ),
  );
}
```

`NoteRepository` is **not** added to the `MultiBlocProvider` list — it's a
repository, exposed via `RepositoryProvider`, not a Cubit. Only app-wide
Cubits (like `FeatureFlagCubit`) go in `MultiBlocProvider` here; the
`NoteListCubit` built in step 6 is screen-scoped and created inside its own
screen instead (AGENTS.md section 8).

Update `test/app_test.dart`/`test/widget_test.dart` call sites that
construct `App(...)` directly to pass the new required `noteRepository`
parameter, or they will fail to compile.

## 6. UI Cubit

`packages/ui/lib/src/features/notes/bloc/note_list_state.dart`:
```dart
import 'package:domain/domain.dart';
import 'package:equatable/equatable.dart';

sealed class NoteListState extends Equatable {
  const NoteListState();

  @override
  List<Object?> get props => [];
}

final class NoteListLoading extends NoteListState {
  const NoteListLoading();
}

final class NoteListLoaded extends NoteListState {
  const NoteListLoaded(this.notes);

  final List<Note> notes;

  @override
  List<Object?> get props => [notes];
}

final class NoteListError extends NoteListState {
  const NoteListError(this.failure);

  final DomainFailure failure;

  @override
  List<Object?> get props => [failure];
}
```

`packages/ui/lib/src/features/notes/bloc/note_list_cubit.dart`:
```dart
import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'note_list_state.dart';

/// Screen-scoped Cubit — created inside `NotesScreen.build` (step 7), not
/// provided app-wide, since only that screen needs it (AGENTS.md section 8).
class NoteListCubit extends Cubit<NoteListState> {
  NoteListCubit(this._repository) : super(const NoteListLoading()) {
    _subscription = _repository.watchAllNotes().listen(
      (notes) => emit(NoteListLoaded(notes)),
      onError: (Object error) {
        if (isClosed) return;
        emit(NoteListError(error as DomainFailure));
      },
    );
  }

  final NoteRepository _repository;
  late final StreamSubscription<List<Note>> _subscription;

  Future<void> addNote(String title, String body) =>
      _repository.createNote(title: title, body: body);

  Future<void> deleteNote(String id) => _repository.deleteNote(id);

  @override
  Future<void> close() {
    unawaited(_subscription.cancel());
    return super.close();
  }
}
```

Note the two AGENTS.md section 16 rules applied here: `if (isClosed) return;`
before the async `emit` in the error handler, and the stream subscription is
cancelled in `close()`. `addNote` delegates straight to the repository and
never picks an id itself — id assignment is `DriftNoteDataProvider`'s job
(step 4), not something the UI layer should have an opinion on.

Barrel: `packages/ui/lib/src/features/notes/bloc/bloc.dart`
```dart
library;

export 'note_list_cubit.dart';
export 'note_list_state.dart';
```

Test: `packages/ui/test/features/notes/bloc/note_list_cubit_test.dart`,
mocking the `domain` repository with `mocktail` (never the data provider
underneath it — `packages/ui/AGENTS.md` → "Testing"):

```dart
// packages/ui/test/features/notes/bloc/note_list_cubit_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ui/ui.dart';

class MockNoteRepository extends Mock implements NoteRepository {}

void main() {
  late MockNoteRepository repository;

  setUp(() {
    repository = MockNoteRepository();
    when(() => repository.watchAllNotes()).thenAnswer((_) => const Stream.empty());
  });

  blocTest<NoteListCubit, NoteListState>(
    'emits NoteListLoaded when the repository stream emits notes',
    setUp: () {
      when(() => repository.watchAllNotes()).thenAnswer(
        (_) => Stream.value([Note(id: '1', title: 'T', body: 'B', updatedAt: DateTime(2026))]),
      );
    },
    build: () => NoteListCubit(repository),
    expect: () => [isA<NoteListLoaded>()],
  );
}
```

## 7. UI screen

`packages/ui/lib/src/features/notes/presentation/notes_screen.dart` — public
`NotesScreen` creates the Cubit; private `_NotesView` consumes it, per
AGENTS.md section 8:

```dart
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../theme/theme.dart';
import '../bloc/bloc.dart';

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => NoteListCubit(context.read<NoteRepository>()),
    child: const _NotesView(),
  );
}

class _NotesView extends StatelessWidget {
  const _NotesView();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.notesScreenTitle)),
    body: Padding(
      padding: const EdgeInsets.all(AppSpacing.pageMargin),
      child: BlocBuilder<NoteListCubit, NoteListState>(builder: (context, state) => _buildBody(context, state)),
    ),
  );

  Widget _buildBody(BuildContext context, NoteListState state) => switch (state) {
    NoteListLoading() => const Center(child: CircularProgressIndicator()),
    NoteListLoaded(:final notes) when notes.isEmpty => Center(child: Text(context.l10n.notesEmptyMessage)),
    NoteListLoaded(:final notes) => ListView.separated(
      itemCount: notes.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.gutter),
      itemBuilder: (context, index) => ListTile(
        title: Text(notes[index].title),
        subtitle: Text(notes[index].body),
        onTap: () => context.read<NoteListCubit>().deleteNote(notes[index].id),
      ),
    ),
    NoteListError() => Center(child: Text(context.l10n.genericErrorMessage)),
  };
}
```

`notesScreenTitle` and `notesEmptyMessage` must be added to
`packages/ui/lib/l10n/app_en.arb`/`app_es.arb` and regenerated with
`fvm flutter gen-l10n` from `packages/ui/` before this compiles — no
hardcoded user-facing string is allowed in `packages/ui/` (AGENTS.md
section 11); `genericErrorMessage` already exists.

Barrels:

`packages/ui/lib/src/features/notes/presentation/presentation.dart`
```dart
library;

export 'notes_screen.dart';
```

`packages/ui/lib/src/features/notes/notes.dart`
```dart
library;

export 'bloc/bloc.dart';
export 'presentation/presentation.dart';
```

`packages/ui/lib/src/features/features.dart`
```dart
library;

export 'home/home.dart';
export 'notes/notes.dart';
```

`packages/ui/lib/ui.dart` needs no edit — it already exports
`src/features/features.dart`, which now carries the new feature through.

Wire the screen into routing (see `.agents/skills/routing/SKILL.md` for the
full pattern) — e.g. add a second branch to the `StatefulShellRoute` in
`packages/ui/lib/src/router/app_router.dart`, or point the existing
`AppRoute.home` at `NotesScreen` if this is the app's first real feature.

Test: `packages/ui/test/features/notes/presentation/notes_screen_test.dart`,
using `pumpApp` (`packages/ui/test/helpers/pump_app.dart`) plus a mocked
`NoteRepository` and a `RepositoryProvider<NoteRepository>.value` wrapped
around it, following the same shape as
`packages/ui/test/features/home/home_screen_test.dart`.

## 8. Definition of done (AGENTS.md section 18)

- [ ] `fvm dart run tool/quality_gate.dart` exits 0.
- [ ] `Note` entity, `NoteDataProvider`, `NoteRepository`,
      `DriftNoteDataProvider`, `NoteListCubit`, `NotesScreen` each have a
      test in this change.
- [ ] No hardcoded user-facing string in `packages/ui/` — every string goes
      through `context.l10n`.
- [ ] No `data` import anywhere in `packages/ui/`; no `flutter`/`data`
      import in `packages/domain/`.
- [ ] Every barrel updated: `entities.dart`, `data_providers.dart` (domain),
      `repositories.dart`; `data_providers.dart` (data); the feature's own
      `notes.dart` and `features.dart`.
- [ ] `App`'s new `noteRepository` parameter is threaded through
      `bootstrap.dart` and every direct `App(...)` construction in tests.
- [ ] Hand back once `fvm dart run tool/quality_gate.dart` passes. The
      **orchestrating session** — not you, if you're a non-delegating
      subagent like `feature-implementer` — runs the `code-review` skill's
      parallel-review protocol before the feature is declared finished.

## Common mistakes

- Defining `NoteRepository` as an `abstract interface class` — repositories
  are concrete in this architecture; only the data-provider layer gets an
  interface (AGENTS.md section 20).
- Providing `NoteListCubit` app-wide in `lib/app.dart`'s `MultiBlocProvider`
  instead of creating it inside `NotesScreen` — it's screen-scoped, not an
  app-wide Cubit like `FeatureFlagCubit`.
- Generating the note's id anywhere in `packages/ui` (inside `NoteListCubit`
  or the screen) instead of letting `DriftNoteDataProvider.createNote`
  assign it — id creation is a `packages/data` concern (AGENTS.md section 2's
  dependency rule), not something the UI layer should pick a strategy for.
- Forgetting to add the new required parameter to every direct `App(...)`
  construction (`test/app_test.dart`, `test/widget_test.dart`), which is a
  compile error, not a runtime one.
- Skipping the barrel-file update at any layer — an unexported file compiles
  inside its own package but is invisible to `package:domain`/`package:data`/
  `package:ui` imports from anywhere else, which surfaces as a confusing
  "not found" error one layer up.
- Interpolating `e.toString()` or a raw `DomainFailure.cause` into the
  screen's error text instead of switching on the failure/state and using
  localized copy (AGENTS.md section 9).
