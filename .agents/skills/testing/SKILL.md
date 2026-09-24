---
name: testing
description: Covers the testing pattern for every layer — domain (package:test with a hand-written Fake data provider, no mocktail), data (an ephemeral real instance or a mocked client), ui Cubit/BLoC (blocTest + mocktail against the domain repository), ui widgets (the pumpApp helper), and router tests (a fresh buildAppRouter() per test); triggers whenever a test is being written for a new entity, provider, repository, Cubit/BLoC, widget, or route.
---

# Testing per layer

Root `AGENTS.md` section 6: every new entity, data provider, repository,
Cubit/BLoC, widget, or route gets a test in the same change that
introduces it. A change is not done until `fvm dart run
tool/quality_gate.dart` passes. Root `AGENTS.md` section 12: mocking
packages and hand-written fakes live under `test/` only, as
`dev_dependencies` — never inside `lib/`.

The rule that matters most across every layer below: **assert the actual
interesting behavior** — the state that gets emitted, the failure that
gets mapped, the widget that gets shown — not just "it runs without
throwing". A test that only calls a method and asserts nothing meaningful
about the result is not a passing bar for "has a test".

## 1. Domain layer: `package:test`, hand-written `Fake*`, no mocking package

`packages/domain` has no Flutter dependency and no `mocktail` dependency
(`packages/domain/pubspec.yaml`) — it uses plain `package:test`. A
repository test uses a hand-written fake implementing the data-provider
interface, not a mock:

```dart
// packages/domain/test/repositories/task_repository_test.dart
import 'package:domain/domain.dart';
import 'package:test/test.dart';

class FakeTaskDataProvider implements TaskDataProvider {
  final List<Task> _tasks = [];

  @override
  Future<List<Task>> getAll() async => List.unmodifiable(_tasks);

  @override
  Future<void> add(Task task) async => _tasks.add(task);
}

void main() {
  group('TaskRepository', () {
    test('getAll returns tasks added through the data provider', () async {
      final provider = FakeTaskDataProvider();
      final repository = TaskRepository(provider);
      final task = Task(id: '1', title: 'Buy milk');

      await repository.add(task);
      final result = await repository.getAll();

      expect(result, [task]);
    });
  });
}
```

This mirrors the shipped example,
`packages/domain/test/repositories/feature_flag_repository_test.dart`,
which constructs a `FeatureFlagRepository` directly (it has no
data-provider to fake) and asserts the actual delegated value:

```dart
test('delegates isEnabled to the underlying FeatureFlags', () {
  const repository = FeatureFlagRepository(FeatureFlags({FeatureFlag.exampleFeature: true}));

  expect(repository.isEnabled(FeatureFlag.exampleFeature), isTrue);
});
```

Put a reusable `Fake*DataProvider` in `packages/domain/test/helpers/` if
more than one test file needs it, rather than redeclaring it per file.

## 2. Data layer: an ephemeral real instance, or a mocked client

`packages/data` uses `flutter_test` (kept for parity, and because most
storage stacks pull in Flutter-plugin dependencies). Prefer a real,
**ephemeral** instance of whatever stack `choose-data-stack` set up (an
in-memory Drift database, a temp-directory Hive box) over mocking it —
this exercises real query/serialization behavior instead of a hand-tuned
stub:

```dart
// packages/data/test/data_providers/drift_task_data_provider_test.dart
import 'package:data/data.dart';
import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DriftTaskDataProvider', () {
    late AppDatabase database;
    late DriftTaskDataProvider provider;

    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      provider = DriftTaskDataProvider(database);
    });

    tearDown(() => database.close());

    test('add then getAll round-trips a task', () async {
      await provider.add(const Task(id: '1', title: 'Buy milk'));

      final tasks = await provider.getAll();

      expect(tasks, [const Task(id: '1', title: 'Buy milk')]);
    });

    test('wraps a constraint violation as a ValidationFailure', () async {
      await provider.add(const Task(id: '1', title: 'Buy milk'));

      // Duplicate primary key — the real database rejects it, and the
      // provider's guard() must translate that into a DomainFailure.
      await expectLater(
        provider.add(const Task(id: '1', title: 'Duplicate')),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });
}
```

Only fall back to a mocked client (`mocktail`) when the chosen stack has
no ephemeral/in-memory mode to test against (e.g. a third-party REST API
with no local fake server) — then mock at the client boundary (`Dio`,
`http.Client`), not the data provider itself:

```dart
class MockDioClient extends Mock implements Dio {}

test('maps a 404 response to NotFoundFailure', () async {
  final client = MockDioClient();
  when(() => client.get(any())).thenThrow(
    DioException(requestOptions: RequestOptions(), response: Response(
      requestOptions: RequestOptions(),
      statusCode: 404,
    )),
  );
  final provider = RestTaskDataProvider(client);

  await expectLater(provider.getAll(), throwsA(isA<NotFoundFailure>()));
});
```

## 3. UI Cubit/BLoC: `blocTest` + `mocktail` on the domain repository

A Cubit/Bloc test mocks the `domain` repository it depends on with
`mocktail` — **never** the data provider underneath it (that's a
different layer's test, per `packages/ui/AGENTS.md`):

```dart
// packages/ui/test/features/tasks/bloc/task_list_cubit_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ui/ui.dart';

class MockTaskRepository extends Mock implements TaskRepository {}

void main() {
  late MockTaskRepository repository;

  setUp(() => repository = MockTaskRepository());

  group('TaskListCubit', () {
    final tasks = [const Task(id: '1', title: 'Buy milk')];

    blocTest<TaskListCubit, TaskListState>(
      'load emits loading then loaded with the repository result',
      setUp: () => when(() => repository.getAll()).thenAnswer((_) async => tasks),
      build: () => TaskListCubit(repository),
      act: (cubit) => cubit.load(),
      expect: () => [
        const TaskListState(status: TaskListStatus.loading),
        TaskListState(status: TaskListStatus.loaded, tasks: tasks),
      ],
      verify: (_) => verify(() => repository.getAll()).called(1),
    );

    blocTest<TaskListCubit, TaskListState>(
      'load emits an error state when the repository throws a DomainFailure',
      setUp: () => when(() => repository.getAll()).thenThrow(const ConnectivityFailure('offline')),
      build: () => TaskListCubit(repository),
      act: (cubit) => cubit.load(),
      expect: () => [
        const TaskListState(status: TaskListStatus.loading),
        const TaskListState(status: TaskListStatus.error, error: TaskListError.connectivity),
      ],
    );
  });
}
```

Both tests assert the actual emitted `TaskListState` values (including
which `TaskListError` the failure mapped to) — not just that `load()`
completed without throwing.

### `registerFallbackValue` for complex argument types

`mocktail`'s `any()` needs a registered fallback for any non-primitive
argument type used with `when`/`verify`, registered once per test run
(typically in a `setUpAll`):

```dart
class FakeTask extends Fake implements Task {}

void main() {
  setUpAll(() => registerFallbackValue(FakeTask()));

  // Now `when(() => repository.add(any())).thenAnswer(...)` works for a
  // Task argument.
}
```

Without it, `any()`/`captureAny()` on a `Task` (or any other non-builtin
type) throws at test setup time, not silently — but registering it up
front avoids the noise entirely.

## 4. UI widgets: `pumpApp`, not per-file provider wiring

`packages/ui/test/helpers/pump_app.dart` wires every app-wide provider a
screen expects (`FeatureFlagRepository` + `FeatureFlagCubit`, theme,
localization delegates) so an individual widget test doesn't redeclare
that boilerplate:

```dart
extension PumpApp on WidgetTester {
  Future<void> pumpApp(Widget widget, {FeatureFlagRepository? featureFlagRepository}) {
    return pumpWidget(
      RepositoryProvider<FeatureFlagRepository>.value(
        value: featureFlagRepository ?? const FeatureFlagRepository(FeatureFlags({})),
        child: BlocProvider(
          create: (context) => FeatureFlagCubit(context.read<FeatureFlagRepository>()),
          child: MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: widget,
          ),
        ),
      ),
    );
  }
}
```

A widget test just calls `tester.pumpApp(const TaskListScreen())` and
asserts on the result — mirroring
`packages/ui/test/features/home/home_screen_test.dart`:

```dart
testWidgets('renders the localized title and placeholder copy', (tester) async {
  await tester.pumpApp(const HomeScreen());

  expect(find.text('Home'), findsOneWidget);
  expect(find.text('Run the new-feature skill to replace this screen.'), findsOneWidget);
});
```

If a new feature needs additional wiring beyond what `pumpApp` provides
(e.g. a `TaskRepository` for a screen that creates its own Cubit), **add
a second pumper to `pump_app.dart`** rather than rebuilding the provider
tree inline in the new test file:

```dart
// packages/ui/test/helpers/pump_app.dart — add alongside pumpApp
extension PumpApp on WidgetTester {
  // ... existing pumpApp ...

  Future<void> pumpAppWithTasks(Widget widget, {required TaskRepository taskRepository}) {
    return pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<FeatureFlagRepository>.value(
            value: const FeatureFlagRepository(FeatureFlags({})),
          ),
          RepositoryProvider<TaskRepository>.value(value: taskRepository),
        ],
        child: BlocProvider(
          create: (context) => FeatureFlagCubit(context.read<FeatureFlagRepository>()),
          child: MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: widget,
          ),
        ),
      ),
    );
  }
}
```

Every subsequent test for a screen that needs a `TaskRepository` reuses
`pumpAppWithTasks` — it is written once, in `test/helpers/`, and never
redeclared per test file.

## 5. Router tests: a fresh `buildAppRouter()` per test

Mirrors the "function, not singleton" rule in
`.agents/skills/routing/SKILL.md`: every router test builds its own
`GoRouter` instance, never sharing one across tests:

```dart
// packages/ui/test/router/app_router_test.dart
Future<void> pumpRouter(WidgetTester tester) {
  // A fresh router per test — no shared navigation state can leak
  // between tests.
  final router = buildAppRouter();
  return tester.pumpWidget(
    RepositoryProvider<FeatureFlagRepository>.value(
      value: const FeatureFlagRepository(FeatureFlags({})),
      child: BlocProvider(
        create: (context) => FeatureFlagCubit(context.read<FeatureFlagRepository>()),
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    ),
  );
}

testWidgets('starts at the home route', (tester) async {
  await pumpRouter(tester);
  await tester.pumpAndSettle();

  expect(find.byType(HomeScreen), findsOneWidget);
});
```

A new route's test follows the same shape: build a fresh router, navigate
with `router.go(AppRoute.taskDetail.path)` (or via a widget tap), and
assert the expected screen type is found — including a redirect-guard
case if the route uses a typed `state.extra` argument (assert it bounces
back to `AppRoute.home.path` when given a wrong/missing `extra`).

## Where new shared fakes/pumpers go

| What | Where |
|---|---|
| `Fake*DataProvider` for a domain repository test | `packages/domain/test/helpers/` |
| `Mock*Repository` class declaration reused by several Cubit tests | inline per test file is fine for a one-line `class MockX extends Mock implements X {}`; only extract if genuinely shared setup grows around it |
| A new `pumpApp`-style widget-test helper | `packages/ui/test/helpers/pump_app.dart` |
| A shared `Fake*` used for `registerFallbackValue` across several test files | `packages/ui/test/helpers/` |

Never declare a `Mock`/`Fake` class inside `lib/` in any package (root
`AGENTS.md` sections 12 and 20) — it belongs in `test/` as a
`dev_dependency`-only construct.

## Common mistakes

- Mocking the data provider in a Cubit/BLoC test instead of the domain
  repository — that skips the layer the Cubit actually depends on and
  couples the test to an implementation detail.
- A test that calls a method and asserts only that no exception was
  thrown, with no assertion on the resulting state/value.
- Redeclaring `pumpApp`'s provider tree inline in a new widget-test file
  instead of adding a second pumper to `pump_app.dart`.
- Sharing one `buildAppRouter()` instance across multiple `testWidgets`
  blocks.
- Forgetting `registerFallbackValue` for a non-primitive `mocktail`
  argument type, or registering it per test instead of once in
  `setUpAll`.
- Adding `mocktail` (or any mocking package) to a package's
  `dependencies` instead of `dev_dependencies`.

## Checklist

- [ ] Domain: `package:test`, hand-written `Fake*DataProvider`, no
      mocking package.
- [ ] Data: an ephemeral real instance of the chosen stack preferred over
      a mock; a mocked client only when no ephemeral mode exists.
- [ ] UI Cubit/BLoC: `blocTest` + `mocktail`, mocking the `domain`
      repository, `registerFallbackValue` registered for any non-primitive
      argument.
- [ ] UI widget: uses `pumpApp` (or a second pumper added to
      `pump_app.dart`), not inline provider wiring.
- [ ] Router: a fresh `buildAppRouter()` built inside the test, not
      shared.
- [ ] Every test asserts the actual interesting outcome (emitted state,
      mapped failure, rendered widget) — not just "it ran".
- [ ] `fvm dart run tool/quality_gate.dart` passes.
