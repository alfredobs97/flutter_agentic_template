import 'package:domain/domain.dart';
import 'package:flutter_agentic_template/app_environment.dart';
import 'package:flutter_agentic_template/feature_flag_defaults.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('featureFlagDefaultsFor', () {
    test('dev enables the example flag', () {
      final defaults = featureFlagDefaultsFor(AppFlavor.dev);

      expect(defaults[FeatureFlag.exampleFeature], isTrue);
    });

    test('prod disables the example flag', () {
      final defaults = featureFlagDefaultsFor(AppFlavor.prod);

      expect(defaults[FeatureFlag.exampleFeature], isFalse);
    });
  });
}
