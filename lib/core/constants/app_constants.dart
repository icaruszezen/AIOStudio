/// Centralised application-wide constants.
///
/// Route constants live in [core/router/app_router.dart] (`AppRoutes`).
/// Breakpoints live in [core/utils/platform_utils.dart] (`Breakpoints`).
abstract final class AppConstants {
  static const String appName = 'AIO Studio';
  static const String dataDirectoryName = 'aio_data';
  static const String databaseFileName = 'aio_studio.sqlite';
}
