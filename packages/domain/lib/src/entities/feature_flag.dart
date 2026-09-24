import 'package:equatable/equatable.dart';

/// A toggle the app checks at runtime. Add a value here when a feature must
/// be enabled/disabled per build flavor (see `lib/feature_flag_defaults.dart`
/// at the app root) without a code change or app-store release.
///
/// This is not a general-purpose remote-config system — it's a small,
/// closed enum on purpose. If you need server-controlled rollout, A/B
/// testing, or per-user targeting, replace `FeatureFlagRepository`'s
/// in-memory `Map` with a remote-config data provider; the `FeatureFlag`
/// enum and `FeatureFlagCubit` in `package:ui` stay the same either way.
enum FeatureFlag {
  /// Example flag — delete once a real one replaces it. Kept so the
  /// template compiles and `FeatureFlagCubit` has something to expose.
  exampleFeature,
}

/// An immutable snapshot of every [FeatureFlag]'s current value.
final class FeatureFlags extends Equatable {
  const FeatureFlags(this._values);

  final Map<FeatureFlag, bool> _values;

  /// Returns whether [flag] is enabled. Flags not present in the underlying
  /// map default to `false` rather than throwing, so adding a new
  /// [FeatureFlag] value is never a breaking change for existing callers.
  bool isEnabled(FeatureFlag flag) => _values[flag] ?? false;

  @override
  List<Object?> get props => [_values];
}
