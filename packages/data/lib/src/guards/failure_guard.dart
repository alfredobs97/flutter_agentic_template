import 'package:domain/domain.dart';

/// Maps an infrastructure exception (Drift, Dio, PlatformException, ...)
/// to the [DomainFailure] subtype it represents.
///
/// Every concrete data-provider implementation supplies its own mapper —
/// what counts as "not found" or "no connectivity" is specific to the
/// package being wrapped. See `.agents/skills/choose-data-stack/SKILL.md`
/// for a ready-made mapper per supported stack (Drift, Dio, Firebase, ...).
///
/// A mapper is only called for an exception that is not already a
/// [DomainFailure] — see [guard]/[guardStream] below, which rethrow an
/// existing [DomainFailure] unchanged so it is never double-wrapped.
typedef FailureMapper = DomainFailure Function(Object error);

/// The default mapper, used when a provider doesn't need per-exception
/// nuance: everything becomes an [UnexpectedFailure]. Prefer a specific
/// [FailureMapper] once you know which exceptions your chosen stack throws
/// for "not found" / "no connectivity" / etc., so `ui` can react to them
/// (see AGENTS.md → "Error handling").
DomainFailure _defaultMapper(Object error) => UnexpectedFailure(error);

/// Runs [action] and translates any exception it throws into a
/// [DomainFailure], using [mapper] (or [_defaultMapper] if omitted).
///
/// Wrap every data-provider method body in `guard`/`guardStream` — see
/// AGENTS.md → "Error handling" for why repositories, Cubits/BLoCs and
/// widgets must never see an infrastructure-specific exception type.
///
/// ```dart
/// @override
/// Future<Task?> getTaskById(String id) => guard(() async {
///       final row = await _db.taskById(id).getSingleOrNull();
///       return row?.toEntity();
///     }, mapper: _mapDriftError);
/// ```
Future<T> guard<T>(Future<T> Function() action, {FailureMapper mapper = _defaultMapper}) async {
  try {
    return await action();
  } on DomainFailure {
    rethrow;
  } catch (error) {
    throw mapper(error);
  }
}

/// The `Stream` counterpart of [guard], for a data-provider method that
/// returns a live `watchX()` stream instead of a `Future`.
Stream<T> guardStream<T>(Stream<T> Function() action, {FailureMapper mapper = _defaultMapper}) {
  return action().handleError(
    (Object error) => throw mapper(error),
    test: (error) => error is! DomainFailure,
  );
}
