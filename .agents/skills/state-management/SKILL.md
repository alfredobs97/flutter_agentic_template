---
name: state-management
description: Explains when to use a plain Cubit vs a full Bloc with events, how to shape a state class (status enum + copyWith vs a sealed hierarchy), the Screen/View split for wiring a Cubit into a widget tree, and the app-wide-vs-screen-scoped Cubit distinction; triggers whenever a new Cubit/BLoC or its state class is being designed.
---

# State management: Cubit vs Bloc, and state shape

This template uses `flutter_bloc` for all state management (root `AGENTS.md`
section 3). `setState` inside a feature screen is forbidden. This skill
covers the two decisions you make every time you add state: **Cubit vs
Bloc**, and **how to shape the state class**.

## 1. Cubit vs Bloc: default to Cubit

A **Cubit** exposes plain methods that call `emit` directly. A **Bloc**
funnels every trigger through `on<Event>` handlers dispatched from a single
`add(event)` call.

Use a **Cubit** for the large majority of screens: a method per user
action, each one loading data, mapping a failure, or updating a field.

```dart
class TaskListCubit extends Cubit<TaskListState> {
  TaskListCubit(this._repository) : super(const TaskListState.initial());

  final TaskRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(status: TaskListStatus.loading));
    try {
      final tasks = await _repository.getAll();
      if (isClosed) return;
      emit(state.copyWith(status: TaskListStatus.loaded, tasks: tasks));
    } on DomainFailure catch (failure) {
      if (isClosed) return;
      emit(state.copyWith(status: TaskListStatus.error, error: _mapFailure(failure)));
    }
  }
}
```

Reach for a full **Bloc** only when you genuinely need several *distinct*
triggers merged into one ordered stream of state changes — not merely
"more than one method". The signal is: two or more independent event
sources (a user tap, a repository stream, a timer) that must be
serialized through the same state machine, or a caller elsewhere in the
codebase needs to dispatch semantically named events (analytics, event
replay, `bloc_concurrency` transformers) rather than call a method
directly. A common concrete case is combining a widget-driven event with
a repository `Stream` via `emit.onEach` inside an event handler:

```dart
class TaskListBloc extends Bloc<TaskListEvent, TaskListState> {
  TaskListBloc(this._repository) : super(const TaskListState.initial()) {
    on<TaskListSubscriptionRequested>(_onSubscriptionRequested);
    on<TaskListFilterChanged>(_onFilterChanged);
  }

  final TaskRepository _repository;
  StreamSubscription<List<Task>>? _subscription;

  Future<void> _onSubscriptionRequested(
    TaskListSubscriptionRequested event,
    Emitter<TaskListState> emit,
  ) async {
    emit(state.copyWith(status: TaskListStatus.loading));
    await emit.onEach<List<Task>>(
      _repository.watchAll(),
      onData: (tasks) => emit(state.copyWith(status: TaskListStatus.loaded, tasks: tasks)),
      onError: (error, stackTrace) =>
          emit(state.copyWith(status: TaskListStatus.error, error: _mapFailure(error))),
    );
  }

  void _onFilterChanged(TaskListFilterChanged event, Emitter<TaskListState> emit) {
    emit(state.copyWith(filter: event.filter));
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
```

If you find yourself reaching for a Bloc just to have named events with no
second trigger source, use a Cubit instead — it is less ceremony for the
same outcome and is what most of this codebase's screens need.

## 2. Shaping the state class

### The majority case: a single class with a status enum + `copyWith`

Most screens have one state *shape* whose fields simply become
populated/empty at different times (loading, loaded, error are all "the
same screen, different data"). Model this as a single `Equatable` class
with a status enum, mirroring the `copyWith`-with-sentinel convention used
for entities (`packages/domain/lib/src/entities/entities.dart`):

```dart
enum TaskListStatus { initial, loading, loaded, error }

class TaskListState extends Equatable {
  const TaskListState({
    this.status = TaskListStatus.initial,
    this.tasks = const [],
    this.error,
  });

  const TaskListState.initial() : this();

  final TaskListStatus status;
  final List<Task> tasks;
  final TaskListError? error;

  TaskListState copyWith({TaskListStatus? status, List<Task>? tasks, TaskListError? error}) =>
      TaskListState(
        status: status ?? this.status,
        tasks: tasks ?? this.tasks,
        // Explicitly nulled by the caller when re-entering a non-error status,
        // not accidentally retained from a previous emit — see below.
        error: error,
      );

  @override
  List<Object?> get props => [status, tasks, error];
}
```

Note the `error` field: a `copyWith` that does `error ?? this.error` would
make an error "sticky" across a subsequent successful load, because
`null` (the caller's intent: "clear it") is indistinguishable from
"unchanged". Either pass `error` through unconditionally (as above, always
supplying the new value explicitly at every call site) or use the
sentinel pattern documented in `entities.dart` if the state has several
independently-clearable nullable fields.

`FeatureFlagState` (`packages/ui/lib/src/app_blocs/feature_flag_state.dart`)
is the trivial end of this spectrum — no status enum at all, because it has
exactly one shape and no loading/error phase. Don't copy its brevity for a
screen that genuinely has multiple phases; the fuller shape above is the
right default.

### The sealed-hierarchy case: genuinely distinct shapes

Reach for a sealed class hierarchy only when different states carry
*different fields*, not just different values of the same fields — e.g. a
form draft state that needs an `editingTaskId` only while editing, and a
list state that has no such concept:

```dart
sealed class TaskFormState extends Equatable {
  const TaskFormState();
}

final class TaskFormEditing extends TaskFormState {
  const TaskFormEditing({required this.title, this.error});

  final String title;
  final ValidationError? error;

  @override
  List<Object?> get props => [title, error];
}

final class TaskFormSubmitting extends TaskFormState {
  const TaskFormSubmitting(this.title);

  final String title;

  @override
  List<Object?> get props => [title];
}

final class TaskFormSubmitted extends TaskFormState {
  const TaskFormSubmitted(this.taskId);

  final String taskId;

  @override
  List<Object?> get props => [taskId];
}
```

The widget then uses an exhaustive `switch` instead of reading a `status`
field, and the analyzer catches a forgotten branch when a new subtype is
added — the same tradeoff `DomainFailure` makes (root `AGENTS.md` section
9). Default to the status-enum shape; only split into a sealed hierarchy
once a single shared field set genuinely stops fitting every phase.

## 3. The Screen/View split

A screen that owns its own Cubit is split into a public `XScreen` (creates
the Cubit) and a private `_XView` (consumes it):

```dart
class TaskListScreen extends StatelessWidget {
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => TaskListCubit(context.read<TaskRepository>())..load(),
    child: const _TaskListView(),
  );
}

class _TaskListView extends StatelessWidget {
  const _TaskListView();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.taskListTitle)),
    body: BlocBuilder<TaskListCubit, TaskListState>(
      builder: (context, state) => _buildBody(context, state),
    ),
  );

  Widget _buildBody(BuildContext context, TaskListState state) => switch (state.status) {
    TaskListStatus.initial || TaskListStatus.loading => const Center(
      child: CircularProgressIndicator(),
    ),
    TaskListStatus.error => _ErrorView(error: state.error!),
    TaskListStatus.loaded => _TaskListContent(tasks: state.tasks),
  };
}
```

`context.read<TaskRepository>()` is used inside `create:` (a one-shot
read, no rebuild dependency); `BlocBuilder` is used inside the view (a
rebuild dependency). Never call `context.read<TaskListCubit>()` for
values you need to *rebuild on* — that's what `BlocBuilder`/`context.watch`
is for.

### App-wide Cubit vs screen-scoped Cubit

Most Cubits are **screen-scoped**: created locally inside that screen's
own `BlocProvider`, as above. A Cubit is **app-wide** only when more than
one screen genuinely needs the same live state — it is provided once,
above `MaterialApp.router`, in `lib/app.dart`:

```dart
// lib/app.dart
BlocProvider(create: (context) => FeatureFlagCubit(context.read<FeatureFlagRepository>()))
```

A screen that only *reads* an app-wide Cubit skips the `BlocProvider` step
entirely and goes straight to `BlocBuilder` — see
`packages/ui/lib/src/features/home/presentation/home_screen.dart`:

```dart
Widget _buildBody(BuildContext context) => BlocBuilder<FeatureFlagCubit, FeatureFlagState>(
  builder: (context, state) => Text(context.l10n.homeScreenPlaceholder),
);
```

Don't wrap a screen in a second `BlocProvider<FeatureFlagCubit>` — that
would shadow the app-wide instance with a fresh one that never receives
the app's real feature-flag data. If you're not sure which category a new
Cubit falls into, default to screen-scoped; promote to app-wide only once
a second screen needs it (the same YAGNI rule `common_widgets/` follows).

## 4. Three correctness rules, every time

- **Guard async emits.** Between an `await` and an `emit`, the Cubit may
  already be closed (the screen was popped mid-request). Always check
  first:

  ```dart
  final tasks = await _repository.getAll();
  if (isClosed) return;
  emit(state.copyWith(tasks: tasks));
  ```

- **Cancel stream subscriptions in `close()`.** Any `StreamSubscription`
  started in the Cubit/Bloc (a `watch()` repository stream, a timer) must
  be cancelled, or it keeps firing (and potentially throws on a closed
  Cubit) after the widget is gone:

  ```dart
  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
  ```

- **Guard `BuildContext` after an `await` in the widget layer.** This is
  the UI-side mirror of the two rules above — after any `await` in a
  callback that touches `context` (e.g. `context.read`, `Navigator`,
  `ScaffoldMessenger`), check `mounted` first:

  ```dart
  onPressed: () async {
    await context.read<TaskListCubit>().delete(taskId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(/* ... */);
  }
  ```

## Checklist

- [ ] Chose Cubit unless there are genuinely multiple distinct event
      sources that need merging through `on<Event>`/`emit.onEach`.
- [ ] State class is a single `Equatable` with a status enum + `copyWith`
      unless different phases need genuinely different fields.
- [ ] `copyWith` does not make a nullable field (e.g. `error`) sticky
      across an unrelated `emit`.
- [ ] Public `XScreen` creates the Cubit via `BlocProvider`; private
      `_XView` consumes it via `BlocBuilder`.
- [ ] Confirmed whether this Cubit is screen-scoped (default) or app-wide
      (provided once in `lib/app.dart`) — and did not re-wrap an app-wide
      Cubit in a local `BlocProvider`.
- [ ] `if (isClosed) return;` before every async `emit`.
- [ ] Every `StreamSubscription` is cancelled in `close()`.
- [ ] `if (!context.mounted) return;` after every `await` that precedes
      `BuildContext` use.
- [ ] A test exists for the Cubit/Bloc (see `.agents/skills/testing/SKILL.md`).
