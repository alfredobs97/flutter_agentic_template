import 'package:domain/domain.dart';
import 'package:equatable/equatable.dart';

/// Wraps [FeatureFlagRepository] so widgets can call
/// `context.watch<FeatureFlagCubit>().state.isEnabled(FeatureFlag.x)`
/// without depending on `domain`'s repository type name directly in a
/// `BlocBuilder<FeatureFlagCubit, X>` generic.
class FeatureFlagState extends Equatable {
  const FeatureFlagState(this._repository);

  final FeatureFlagRepository _repository;

  bool isEnabled(FeatureFlag flag) => _repository.isEnabled(flag);

  @override
  List<Object?> get props => [_repository];
}
