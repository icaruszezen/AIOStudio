import 'package:aio_studio/core/router/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppRoutes', () {
    test('all route paths start with /', () {
      final routes = [
        AppRoutes.projects,
        AppRoutes.assets,
        AppRoutes.aiChat,
        AppRoutes.aiImage,
        AppRoutes.aiVideo,
        AppRoutes.prompts,
        AppRoutes.settings,
      ];

      for (final route in routes) {
        expect(
          route,
          startsWith('/'),
          reason: 'Route "$route" should start with /',
        );
      }
    });

    test('all route paths are unique', () {
      final routes = [
        AppRoutes.projects,
        AppRoutes.assets,
        AppRoutes.aiChat,
        AppRoutes.aiImage,
        AppRoutes.aiVideo,
        AppRoutes.prompts,
        AppRoutes.settings,
      ];

      expect(routes.toSet().length, routes.length);
    });

    test('route paths have expected values', () {
      expect(AppRoutes.projects, '/projects');
      expect(AppRoutes.assets, '/assets');
      expect(AppRoutes.aiChat, '/ai-chat');
      expect(AppRoutes.aiImage, '/ai-image');
      expect(AppRoutes.aiVideo, '/ai-video');
      expect(AppRoutes.prompts, '/prompts');
      expect(AppRoutes.settings, '/settings');
    });

    test('route paths do not contain trailing slashes', () {
      final routes = [
        AppRoutes.projects,
        AppRoutes.assets,
        AppRoutes.aiChat,
        AppRoutes.aiImage,
        AppRoutes.aiVideo,
        AppRoutes.prompts,
        AppRoutes.settings,
      ];

      for (final route in routes) {
        expect(
          route.endsWith('/'),
          isFalse,
          reason: 'Route "$route" should not end with /',
        );
      }
    });
  });
}
