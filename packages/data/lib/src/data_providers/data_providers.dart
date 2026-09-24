/// Barrel for `data_providers/` — currently empty by design.
///
/// A concrete data provider `implements` an interface from
/// `package:domain/src/data_providers/`, wraps a specific storage/network
/// package (Drift, Dio, Hive, Firebase, ...), and translates its
/// exceptions into a `DomainFailure` via `guard`/`guardStream`
/// (`../guards/failure_guard.dart`).
///
/// This package intentionally has **no storage or network dependency**
/// pre-installed — the template is data-stack agnostic. Run
/// `.agents/skills/choose-data-stack/SKILL.md` to add Drift, sqflite, Hive,
/// Isar, ObjectBox, Dio/Retrofit, Firebase or Supabase; it adds the
/// dependency, a `FailureMapper` for that package's exceptions, a
/// provider skeleton, and a test harness (in-memory DB or a mocked client,
/// depending on the stack).
///
/// Export every data-provider implementation file from this barrel.
library;
