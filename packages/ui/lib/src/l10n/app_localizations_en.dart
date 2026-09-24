// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Flutter Agentic Template';

  @override
  String get homeScreenTitle => 'Home';

  @override
  String get homeScreenPlaceholder => 'Run the new-feature skill to replace this screen.';

  @override
  String get genericErrorMessage => 'Something went wrong. Please try again.';

  @override
  String get routeNotFoundTitle => 'Page not found';

  @override
  String get routeNotFoundMessage => 'The page you\'re looking for doesn\'t exist.';

  @override
  String get goHomeButtonLabel => 'Go home';
}
