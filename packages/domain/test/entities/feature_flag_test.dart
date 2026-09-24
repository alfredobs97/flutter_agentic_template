import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('FeatureFlags', () {
    test('isEnabled returns the stored value', () {
      const flags = FeatureFlags({FeatureFlag.exampleFeature: true});

      expect(flags.isEnabled(FeatureFlag.exampleFeature), isTrue);
    });

    test('isEnabled defaults to false for a flag missing from the map', () {
      const flags = FeatureFlags({});

      expect(flags.isEnabled(FeatureFlag.exampleFeature), isFalse);
    });

    test('supports value equality', () {
      const a = FeatureFlags({FeatureFlag.exampleFeature: true});
      const b = FeatureFlags({FeatureFlag.exampleFeature: true});

      expect(a, equals(b));
    });
  });
}
