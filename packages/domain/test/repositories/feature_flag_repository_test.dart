import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('FeatureFlagRepository', () {
    test('delegates isEnabled to the underlying FeatureFlags', () {
      const repository = FeatureFlagRepository(
        FeatureFlags({FeatureFlag.exampleFeature: true}),
      );

      expect(repository.isEnabled(FeatureFlag.exampleFeature), isTrue);
    });
  });
}
