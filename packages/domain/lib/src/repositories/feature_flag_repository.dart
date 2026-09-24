import '../entities/feature_flag.dart';

/// Holds the [FeatureFlags] resolved for the current app flavor.
///
/// This is the one repository the template ships fully implemented — every
/// other repository is deliberately absent (see the `repositories/` folder
/// doc comment and `.agents/skills/new-feature/SKILL.md`). It's a plain
/// in-memory holder, not backed by a `data_provider`, because its values
/// come from `lib/feature_flag_defaults.dart` at process start, not from a
/// database or network call — there is nothing to abstract behind an
/// interface, and no `data`-layer implementation to swap in.
final class FeatureFlagRepository {
  const FeatureFlagRepository(this._flags);

  final FeatureFlags _flags;

  bool isEnabled(FeatureFlag flag) => _flags.isEnabled(flag);
}
