// Uses dart:io (File / Image.file) -- desktop & mobile only; not web-compatible.
import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/platform_utils.dart';
import '../../../shared/widgets/breadcrumb_navigation.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../providers/projects_provider.dart';
import 'project_create_dialog.dart';

class ProjectDetailPage extends ConsumerStatefulWidget {
  const ProjectDetailPage({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends ConsumerState<ProjectDetailPage> {
  int _currentTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final asyncProject = ref.watch(projectDetailProvider(widget.projectId));

    return asyncProject.when(
      loading: () => const ScaffoldPage(
        content: LoadingIndicator(message: '加载项目详情...'),
      ),
      error: (e, _) => ScaffoldPage(
        content: Center(
          child: InfoBar(
            title: const Text('加载失败'),
            content: Text('$e'),
            severity: InfoBarSeverity.error,
          ),
        ),
      ),
      data: (project) {
        if (project == null) {
          return ScaffoldPage(
            content: EmptyState(
              icon: FluentIcons.error,
              title: '项目不存在',
              description: '该项目可能已被删除',
              action: Button(
                onPressed: () => context.go('/projects'),
                child: const Text('返回项目列表'),
              ),
            ),
          );
        }
        return _buildContent(context, project);
      },
    );
  }

  Widget _buildContent(BuildContext context, Project project) {
    final theme = FluentTheme.of(context);

    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: BreadcrumbNavigation(
              items: [
                BreadcrumbEntry(
                  label: '项目',
                  onTap: () => context.go('/projects'),
                ),
                BreadcrumbEntry(label: project.name),
              ],
            ),
          ),
          _buildHeader(theme, project),
          const Divider(),
          Expanded(
            child: _buildTabView(theme, project),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(FluentThemeData theme, Project project) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCoverThumbnail(theme, project),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(project.name, style: theme.typography.subtitle),
                if (project.description != null &&
                    project.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    project.description!,
                    style: theme.typography.body?.copyWith(
                      color: theme.resources.textFillColorSecondary,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Button(
            onPressed: () =>
                ProjectCreateDialog.show(context, existing: project),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FluentIcons.edit, size: 14),
                SizedBox(width: 6),
                Text('编辑'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverThumbnail(FluentThemeData theme, Project project) {
    final hasCover =
        project.coverImagePath != null && project.coverImagePath!.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 80,
        height: 56,
        child: hasCover
            ? Image.file(
                File(project.coverImagePath!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    _buildMiniPlaceholder(theme, project),
              )
            : _buildMiniPlaceholder(theme, project),
      ),
    );
  }

  Widget _buildMiniPlaceholder(FluentThemeData theme, Project project) {
    return Container(
      color: theme.accentColor.withValues(alpha: 0.15),
      child: Center(
        child: Icon(
          FluentIcons.project_management,
          size: 20,
          color: theme.accentColor,
        ),
      ),
    );
  }

  Widget _buildTabView(FluentThemeData theme, Project project) {
    return TabView(
      currentIndex: _currentTabIndex,
      onChanged: (i) => setState(() => _currentTabIndex = i),
      closeButtonVisibility: CloseButtonVisibilityMode.never,
      tabWidthBehavior: PlatformUtils.isMobile
          ? TabWidthBehavior.equal
          : TabWidthBehavior.sizeToContent,
      tabs: [
        Tab(
          text: const Text('资产'),
          icon: const Icon(FluentIcons.photo_collection, size: 14),
          body: _buildPlaceholderTab(
            theme,
            icon: FluentIcons.photo_collection,
            title: '资产管理',
            description: '此功能将在后续阶段实现',
          ),
        ),
        Tab(
          text: const Text('提示词'),
          icon: const Icon(FluentIcons.text_document, size: 14),
          body: _buildPlaceholderTab(
            theme,
            icon: FluentIcons.text_document,
            title: '提示词管理',
            description: '此功能将在后续阶段实现',
          ),
        ),
        Tab(
          text: const Text('AI 任务'),
          icon: const Icon(FluentIcons.processing, size: 14),
          body: _buildPlaceholderTab(
            theme,
            icon: FluentIcons.processing,
            title: 'AI 任务历史',
            description: '此功能将在后续阶段实现',
          ),
        ),
        Tab(
          text: const Text('统计'),
          icon: const Icon(FluentIcons.chart, size: 14),
          body: _buildStatsTab(theme, project),
        ),
      ],
    );
  }

  Widget _buildPlaceholderTab(
    FluentThemeData theme, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return EmptyState(
      icon: icon,
      title: title,
      description: description,
    );
  }

  Widget _buildStatsTab(FluentThemeData theme, Project project) {
    final asyncStats = ref.watch(projectStatsProvider(project.id));

    return asyncStats.when(
      loading: () => const LoadingIndicator(message: '加载统计数据...'),
      error: (e, _) => Center(
        child: InfoBar(
          title: const Text('加载统计失败'),
          content: Text('$e'),
          severity: InfoBarSeverity.error,
        ),
      ),
      data: (stats) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _StatCard(
                icon: FluentIcons.photo_collection,
                label: '总资产',
                value: '${stats.totalAssets}',
                accentColor: theme.accentColor,
              ),
              _StatCard(
                icon: FluentIcons.image_search,
                label: '图片',
                value: '${stats.imageCount}',
                accentColor: const Color(0xFF3B82F6),
              ),
              _StatCard(
                icon: FluentIcons.video,
                label: '视频',
                value: '${stats.videoCount}',
                accentColor: const Color(0xFF8B5CF6),
              ),
              _StatCard(
                icon: FluentIcons.text_document,
                label: '提示词',
                value: '${stats.promptCount}',
                accentColor: const Color(0xFF10B981),
              ),
              _StatCard(
                icon: FluentIcons.processing,
                label: 'AI 任务',
                value: '${stats.aiTaskCount}',
                accentColor: const Color(0xFFF59E0B),
              ),
              _StatCard(
                icon: FluentIcons.diagnostic,
                label: 'Token 消耗',
                value: _formatTokenCount(stats.totalTokenUsage),
                accentColor: const Color(0xFFEF4444),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTokenCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return '$count';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accentColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return SizedBox(
      width: 180,
      child: Card(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, size: 16, color: accentColor),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: theme.typography.subtitle?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
