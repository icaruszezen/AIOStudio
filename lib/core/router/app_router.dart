import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/assets/views/asset_detail_page.dart';
import '../../features/assets/views/assets_page.dart';
import '../../features/projects/views/project_detail_page.dart';
import '../../features/projects/views/projects_page.dart';
import '../../shared/widgets/app_shell.dart';

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
    initialLocation: AppRoutes.projects,
    routes: [
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
            builder: (context, state) =>
                const _PlaceholderPage(title: 'AI 对话'),
          ),
          GoRoute(
            path: AppRoutes.aiImage,
            builder: (context, state) =>
                const _PlaceholderPage(title: '图片生成'),
          ),
          GoRoute(
            path: AppRoutes.aiVideo,
            builder: (context, state) =>
                const _PlaceholderPage(title: '视频生成'),
          ),
          GoRoute(
            path: AppRoutes.prompts,
            builder: (context, state) =>
                const _PlaceholderPage(title: '提示词库'),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (context, state) =>
                const _PlaceholderPage(title: '设置'),
          ),
        ],
      ),
    ],
  );
});

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      content: Center(
        child: Text(
          title,
          style: FluentTheme.of(context).typography.title,
        ),
      ),
    );
  }
}
