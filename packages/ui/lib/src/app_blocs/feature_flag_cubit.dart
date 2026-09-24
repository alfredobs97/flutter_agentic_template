import 'package:domain/domain.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'feature_flag_state.dart';

/// Exposes [FeatureFlagRepository] to the widget tree.
///
/// This is one of the few app-wide Cubits — created once in `lib/app.dart`
/// (at the app root) and provided above `MaterialApp.router`, rather than
/// scoped to a single screen. A screen-scoped Cubit (the common case) is
/// instead created inside that screen's `build` method — see
/// `.agents/skills/state-management/SKILL.md`.
class FeatureFlagCubit extends Cubit<FeatureFlagState> {
  FeatureFlagCubit(this._repository) : super(FeatureFlagState(_repository));

  // Kept for when this Cubit grows beyond a static initial state (e.g. a
  // future watchFlags() stream) and needs it again.
  // ignore: unused_field
  final FeatureFlagRepository _repository;
}
