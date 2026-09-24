/// The build flavor, resolved once from `--dart-define=FLAVOR`.
///
/// Every `flutter run`/`flutter build` invocation MUST pass **both**
/// `--flavor <dev|prod>` and `--dart-define=FLAVOR=<dev|prod>`, and the two
/// must always agree — `AppEnvironment` reads the dart-define; the native
/// `--flavor` selects the Android `productFlavor` / iOS scheme. A
/// `--flavor prod` build carrying `--dart-define=FLAVOR=dev` would install
/// as the production app while reporting itself as dev everywhere in the
/// UI. Use the `.vscode/launch.json` configurations instead of hand-typing
/// the flags — see AGENTS.md → "Flavors".
enum AppFlavor { dev, prod }

abstract final class AppEnvironment {
  static const String _name = String.fromEnvironment('FLAVOR', defaultValue: 'dev');

  static AppFlavor get flavor => _name == 'prod' ? AppFlavor.prod : AppFlavor.dev;

  static bool get isDev => flavor == AppFlavor.dev;

  static String get appTitleSuffix => isDev ? ' (Dev)' : '';
}
