/// The sealed failure hierarchy for the whole app.
///
/// `data` providers MUST translate every infrastructure exception (a
/// database error, a failed HTTP call, a parsing error, ...) into one of
/// these at the provider boundary — see `guard`/`guardStream` in
/// `package:data/src/guards/failure_guard.dart` — so that repositories,
/// Cubits/BLoCs and widgets in `ui` never see an infrastructure-specific
/// exception type (`DioException`, `DriftRuntimeException`, ...).
///
/// It `implements Exception` (not `Error`) because a failure here is an
/// expected, recoverable outcome — a network drop, a 404, invalid user
/// input — not a programming bug. Being `sealed` lets a `switch` over
/// `DomainFailure` be exhaustive, so the analyzer catches a forgotten case
/// the moment a new subtype is added.
///
/// These five cover the large majority of real apps. Add a new subtype only
/// when a caller genuinely needs to react differently to it (see
/// `.agents/skills/error-handling/SKILL.md`); resist adding one "just in
/// case" — an unused branch in every downstream `switch` is a maintenance
/// tax, not safety.
sealed class DomainFailure implements Exception {
  const DomainFailure(this.cause);

  /// The original exception/error that triggered this failure, kept for
  /// logging. Never shown to the user directly — see AGENTS.md → "Error
  /// handling" for why `cause.toString()` must not leak into UI state.
  final Object cause;

  @override
  String toString() => '$runtimeType(cause: $cause)';
}

/// An operation failed for a reason that doesn't fit a more specific
/// failure below — the default translation for an unexpected exception.
final class UnexpectedFailure extends DomainFailure {
  const UnexpectedFailure(super.cause);
}

/// The requested resource does not exist (e.g. a 404, or a database row
/// that was deleted concurrently).
final class NotFoundFailure extends DomainFailure {
  const NotFoundFailure(super.cause);
}

/// The caller supplied data that failed a domain rule (e.g. a required
/// field was empty, a value was out of range). Distinct from a Dart-level
/// `ArgumentError`: this failure crosses the data/domain boundary and is
/// expected to reach the UI as a user-facing message.
final class ValidationFailure extends DomainFailure {
  const ValidationFailure(super.cause);
}

/// The device has no network access, or a remote call timed out /
/// could not reach the server.
final class ConnectivityFailure extends DomainFailure {
  const ConnectivityFailure(super.cause);
}

/// The caller is not allowed to perform this operation — an expired
/// session, a missing permission, a 401/403 response.
final class UnauthorizedFailure extends DomainFailure {
  const UnauthorizedFailure(super.cause);
}
