// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Flutter Agentic Template';

  @override
  String get homeScreenTitle => 'Inicio';

  @override
  String get homeScreenPlaceholder => 'Ejecuta la skill new-feature para sustituir esta pantalla.';

  @override
  String get genericErrorMessage => 'Algo salió mal. Inténtalo de nuevo.';

  @override
  String get routeNotFoundTitle => 'Página no encontrada';

  @override
  String get routeNotFoundMessage => 'La página que buscas no existe.';

  @override
  String get goHomeButtonLabel => 'Ir al inicio';
}
