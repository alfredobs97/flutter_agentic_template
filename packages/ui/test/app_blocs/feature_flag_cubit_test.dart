import 'package:bloc_test/bloc_test.dart';
import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/ui.dart';

void main() {
  group('FeatureFlagCubit', () {
    test('the initial state reflects the injected repository', () {
      const repository = FeatureFlagRepository(FeatureFlags({FeatureFlag.exampleFeature: true}));

      final cubit = FeatureFlagCubit(repository);
      addTearDown(cubit.close);

      expect(cubit.state.isEnabled(FeatureFlag.exampleFeature), isTrue);
    });

    blocTest<FeatureFlagCubit, FeatureFlagState>(
      'emits no further states once created',
      build: () => FeatureFlagCubit(const FeatureFlagRepository(FeatureFlags({}))),
      expect: () => <FeatureFlagState>[],
    );
  });
}
