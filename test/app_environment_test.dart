import 'package:flutter_agentic_template/app_environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppEnvironment', () {
    test('defaults to dev when FLAVOR is not defined', () {
      // No --dart-define=FLAVOR is passed to `flutter test`, so this
      // exercises the documented default in app_environment.dart.
      expect(AppEnvironment.flavor, AppFlavor.dev);
      expect(AppEnvironment.isDev, isTrue);
    });
  });
}
