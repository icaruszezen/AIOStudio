// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class SEn extends S {
  SEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'AIO Studio';

  @override
  String get navProjects => 'Projects';

  @override
  String get navAssets => 'Assets';

  @override
  String get navChat => 'AI Chat';

  @override
  String get navImageGen => 'AI Image';

  @override
  String get navVideoGen => 'AI Video';

  @override
  String get navPrompts => 'Prompts';

  @override
  String get navSettings => 'Settings';

  @override
  String get actionRetry => 'Retry';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionSave => 'Save';

  @override
  String get actionCreate => 'New';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionSearch => 'Search';

  @override
  String get emptyStateCreateFirst => 'Get Started';

  @override
  String get loadingGeneric => 'Loading...';

  @override
  String get errorGeneric => 'Operation failed. Please try again later.';

  @override
  String get errorNetwork =>
      'Network connection failed. Check your network or proxy settings.';

  @override
  String get errorTimeout => 'Request timed out. Please try again later.';

  @override
  String get errorFileSystem =>
      'File operation failed. Check storage permissions.';

  @override
  String get errorDatabase => 'Database operation failed. Please try again.';

  @override
  String get pageNotFoundTitle => 'Page Not Found';

  @override
  String get pageNotFoundDescription =>
      'The page you are looking for does not exist or has been removed.';

  @override
  String get pageNotFoundAction => 'Go Home';

  @override
  String get genFailedTitle => 'Generation Failed';

  @override
  String extensionImportSaved(String name) {
    return 'Saved from browser: $name';
  }

  @override
  String get actionView => 'View';
}
