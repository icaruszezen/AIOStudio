/// Centralised application-wide constants.
///
/// Route constants live in [core/router/app_router.dart] (`AppRoutes`).
/// Breakpoints live in [core/utils/platform_utils.dart] (`Breakpoints`).
abstract final class AppConstants {
  static const String appName = 'AIO Studio';
  static const String dataDirectoryName = 'aio_data';
  static const String databaseFileName = 'aio_studio.sqlite';

  // -- External URLs --
  static const String githubRepoUrl =
      'https://github.com/icaruszezen/AIOStudio';

  // -- Network defaults --
  static const Duration defaultConnectTimeout = Duration(seconds: 30);
  static const Duration defaultReceiveTimeout = Duration(seconds: 120);

  // -- AI service defaults --
  static const int defaultMaxContextMessages = 50;
  static const int defaultHistoryPageSize = 50;
}
