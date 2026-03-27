import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/notification_service.dart';
import '../../features/ai_chat/views/chat_page.dart';
import '../../features/ai_image/views/image_gen_page.dart';
import '../../features/ai_video/views/video_gen_page.dart';
import '../../features/assets/views/asset_detail_page.dart';
import '../../features/assets/views/assets_page.dart';
import '../../features/projects/views/project_detail_page.dart';
import '../../features/projects/views/projects_page.dart';
import '../../features/prompts/views/prompts_page.dart';
import '../../features/settings/views/settings_page.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/not_found_page.dart';

abstract final class AppRoutes {
  static const projects = '/projects';
  static const assets = '/assets';
  static const aiChat = '/ai-chat';
  static const aiImage = '/ai-image';
  static const aiVideo = '/ai-video';
  static const prompts = '/prompts';
  static const settings = '/settings';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: NotificationService.navigatorKey,
    initialLocation: AppRoutes.projects,
    errorBuilder: (context, state) => const NotFoundPage(),
    routes: [
      // ShellRoute uses the default internal navigator for its children.
      // If full-screen overlays outside the shell are needed in the future,
      // add a dedicated navigatorKey here and parentNavigatorKey on those routes.
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.projects,
            builder: (context, state) => const ProjectsPage(),
            routes: [
              GoRoute(
                path: ':projectId',
                builder: (context, state) {
                  final id = state.pathParameters['projectId']!;
                  return ProjectDetailPage(projectId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.assets,
            builder: (context, state) => const AssetsPage(),
            routes: [
              GoRoute(
                path: ':assetId',
                builder: (context, state) {
                  final id = state.pathParameters['assetId']!;
                  return AssetDetailPage(assetId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.aiChat,
            builder: (context, state) => const ChatPage(),
          ),
          GoRoute(
            path: AppRoutes.aiImage,
            builder: (context, state) => const ImageGenPage(),
          ),
          GoRoute(
            path: AppRoutes.aiVideo,
            builder: (context, state) => const VideoGenPage(),
          ),
          GoRoute(
            path: AppRoutes.prompts,
            builder: (context, state) => const PromptsPage(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (context, state) => const SettingsPage(),
          ),
        ],
      ),
    ],
  );
});
