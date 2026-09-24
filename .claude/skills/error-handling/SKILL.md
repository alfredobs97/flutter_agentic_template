---
name: error-handling
description: Explains when to add a new DomainFailure subtype versus reuse one of the five existing ones, how to write a FailureMapper for a data provider using guard/guardStream, and how a Cubit maps a DomainFailure to a UI-facing error value instead of leaking exception text into state; load before designing a new failure type or wiring error handling from a data provider through to a widget.
---

# Error handling

This template's error model is `packages/domain/lib/src/failures/domain_failure.dart`:
a `sealed class DomainFailure` with five subtypes — `UnexpectedFailure`,
`NotFoundFailure`, `ValidationFailure`, `ConnectivityFailure`,
`UnauthorizedFailure`. Every infrastructure exception (Drift, Dio,
`PlatformException`, ...) is translated into one of these at the `data`
provider boundary. Nothing above `data` — no repository, no Cubit/BLoC, no
widget — ever sees an infrastructure-specific exception type. See root
`AGENTS.md` section 9 for the rule; this skill covers the judgment calls.

## 1. When to add a new `DomainFailure` subtype

**Default: don't.** The five subtypes cover the large majority of real
apps, and `DomainFailure` being `sealed` means every `switch` over it must
be exhaustive — a new subtype forces the analyzer to flag every `switch`
in the codebase that doesn't handle it yet. That's a deliberate cost, not
an accident, so it should only be paid when it buys something real.

The bar is: **does a caller need to react differently to this failure**,
not "is this conceptually a distinct kind of error". Concretely:

- A caller "reacts differently" when a Cubit needs to show different UI
  copy, retry logic, or navigation for this failure versus the closest
  existing subtype — e.g. `UnauthorizedFailure` should trigger a
  sign-out-and-redirect-to-login flow that `UnexpectedFailure` must not.
- A caller does **not** need a new subtype just because the underlying
  infrastructure exception has a distinct name. A Drift
  `SqliteException` with code 787 (foreign-key violation) and a Drift
  `InvalidDataException` are different exceptions, but if both should
  surface to the UI as "the data you entered is invalid", they both map
  to `ValidationFailure` — one new case in a `FailureMapper`'s `switch`,
  zero new `DomainFailure` subtypes.

Worked examples:

- **Add one**: your app has a paid tier, and calls beyond a user's quota
  must show a distinct "upgrade your plan" screen instead of a generic
  error. `NotFoundFailure`/`ValidationFailure`/etc. all read as "something
  is wrong with this request", none of them means "you need to upgrade" —
  add `QuotaExceededFailure`.
- **Don't add one**: a new data provider throws a `FormatException` when
  a response body is malformed JSON. The UI has no different behavior for
  "malformed response" versus "unexpected server error" — both are
  `UnexpectedFailure`. Adding `MalformedResponseFailure` here would be an
  unused branch in every downstream `switch`, not a safety net.

When you do add one, follow the same shape as the existing five: a
`final class` extending `DomainFailure`, a doc comment describing exactly
what triggers it, `const` constructor forwarding to `super.cause`. Add it
to `domain_failure_test.dart`'s `isA<Exception>()` list and its exhaustive
`switch` test (see section 4).

## 2. Writing a `FailureMapper` for a new data provider

A `FailureMapper` is `DomainFailure Function(Object error)` — see
`packages/data/lib/src/guards/failure_guard.dart`. Every concrete data
provider supplies its own, because what counts as "not found" or "no
connectivity" is specific to the package being wrapped. `guard`/
`guardStream` call your mapper only for an exception that isn't already a
`DomainFailure` (an existing one is rethrown unchanged, never
double-wrapped).

Worked example for a made-up `TaskApiClient` (a thin Dio-style wrapper)
throwing its own exception types:

```dart
// packages/data/lib/src/data_providers/api_task_data_provider.dart
import 'package:domain/domain.dart';

import '../data_sources/task_api_client.dart';

DomainFailure _mapTaskApiError(Object error) => switch (error) {
  ApiNotFoundException() => NotFoundFailure(error),
  ApiTimeoutException() => ConnectivityFailure(error),
  ApiUnauthorizedException() => UnauthorizedFailure(error),
  _ => UnexpectedFailure(error),
};

final class ApiTaskDataProvider implements TaskDataProvider {
  ApiTaskDataProvider(this._client);

  final TaskApiClient _client;

  @override
  Future<Task?> getTaskById(String id) => guard(() async {
        final response = await _client.getTask(id);
        return response?.toEntity();
      }, mapper: _mapTaskApiError);

  @override
  Stream<List<Task>> watchTasks() => guardStream(
        () => _client.watchTasks().map((list) => list.map((r) => r.toEntity()).toList()),
        mapper: _mapTaskApiError,
      );
}
```

Notes:

- `_mapTaskApiError` is a private top-level function in the provider
  file, not a shared "mapper layer" — each provider's exceptions are
  specific to it (root `AGENTS.md` → "Models/mappers" in
  `packages/data/AGENTS.md`).
- The `_ => UnexpectedFailure(error)` fallback is required: a mapper must
  handle every exception the wrapped package can throw, and new/unknown
  exception types should degrade to `UnexpectedFailure` rather than
  crash the mapper itself.
- Wrap **every** provider method body in `guard`/`guardStream`, even one
  that "can't fail" — a package upgrade can introduce a new failure mode
  silently.
- Use `guard` for a `Future`-returning method, `guardStream` for a
  `watchX()` stream method — see the `TaskDataProvider` example above for
  both.

## 3. Mapping a `DomainFailure` to UI state — the wrong way and the right way

Root `AGENTS.md` section 9 and section 20 both call this out: a
Cubit/BLoC must never store `e.toString()` (or otherwise interpolate a
caught exception) into state a widget renders. A raw exception message is
not localized, not user-appropriate, and leaks implementation detail
(stack traces, SQL, HTTP bodies) into the UI.

**Wrong:**

```dart
// DON'T: raw exception text reaches the widget.
class TaskListState extends Equatable {
  const TaskListState({this.errorMessage});

  final String? errorMessage;

  @override
  List<Object?> get props => [errorMessage];
}

class TaskListCubit extends Cubit<TaskListState> {
  TaskListCubit(this._repository) : super(const TaskListState());

  final TaskRepository _repository;

  Future<void> load() async {
    try {
      final tasks = await _repository.getTasks();
      emit(TaskListState(tasks: tasks));
    } on DomainFailure catch (e) {
      emit(TaskListState(errorMessage: e.toString())); // leaks "NotFoundFailure(cause: ...)"
    }
  }
}
```

**Right:** a small sealed class (or enum, if every case is a fixed,
data-less reason) of UI-facing error values, mapped from `DomainFailure`
via an exhaustive `switch` — kept in the feature's `bloc/` folder, next
to its state:

```dart
// packages/ui/lib/src/features/tasks/bloc/task_list_error.dart
import 'package:domain/domain.dart';

/// UI-facing reasons the task list failed to load. A widget switches on
/// this — never on [DomainFailure] directly — to pick localized copy.
enum TaskListError { notFound, offline, unauthorized, unexpected }

TaskListError _mapFailureToUiError(DomainFailure failure) => switch (failure) {
  NotFoundFailure() => TaskListError.notFound,
  ConnectivityFailure() => TaskListError.offline,
  UnauthorizedFailure() => TaskListError.unauthorized,
  ValidationFailure() || UnexpectedFailure() => TaskListError.unexpected,
};
```

```dart
// packages/ui/lib/src/features/tasks/bloc/task_list_cubit.dart
class TaskListCubit extends Cubit<TaskListState> {
  TaskListCubit(this._repository) : super(const TaskListState());

  final TaskRepository _repository;

  Future<void> load() async {
    emit(state.copyWith(status: TaskListStatus.loading));
    try {
      final tasks = await _repository.getTasks();
      if (isClosed) return;
      emit(state.copyWith(status: TaskListStatus.success, tasks: tasks));
    } on DomainFailure catch (failure) {
      if (isClosed) return;
      emit(state.copyWith(status: TaskListStatus.failure, error: _mapFailureToUiError(failure)));
    }
  }
}
```

The widget then switches on `TaskListError`, never on `DomainFailure`, to
pick localized copy via `context.l10n` (never a hardcoded string — root
`AGENTS.md` section 11):

```dart
String _errorMessage(BuildContext context, TaskListError error) => switch (error) {
  TaskListError.notFound => context.l10n.taskListNotFoundMessage,
  TaskListError.offline => context.l10n.taskListOfflineMessage,
  TaskListError.unauthorized => context.l10n.taskListUnauthorizedMessage,
  TaskListError.unexpected => context.l10n.genericErrorMessage, // already in app_en.arb
};
```

`genericErrorMessage` already exists in
`packages/ui/lib/l10n/app_en.arb` as the fallback copy for an
unmapped/unexpected failure — reuse it rather than adding a near-duplicate
key per feature.

## 4. Testing a new failure or mapper

Follow the existing tests as the pattern, don't invent a new style:

- **A new `DomainFailure` subtype**: extend
  `packages/domain/test/failures/domain_failure_test.dart` — add it to
  the `isA<Exception>()` list, and add a case to the exhaustive `switch`
  test so a forgotten case fails compilation, not just the test.
- **A new `FailureMapper`**: follow
  `packages/data/test/guards/failure_guard_test.dart`'s shape — one test
  per exception type your mapper handles (asserts the right
  `DomainFailure` subtype comes out), one test confirming an unmapped
  exception falls back to `UnexpectedFailure`, and one confirming an
  already-`DomainFailure` error is rethrown unchanged (`guard`/
  `guardStream` do this for you, but a provider-level test should still
  cover it if the provider does any of its own error handling before the
  guard).
- **A Cubit's `DomainFailure` → UI-error mapping**: use `bloc_test` to
  assert the emitted state's UI-error value for each `DomainFailure`
  subtype the Cubit can receive — never assert on `state.toString()` or
  any exception text.
