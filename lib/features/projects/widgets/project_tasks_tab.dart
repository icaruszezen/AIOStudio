import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/format_utils.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../providers/projects_provider.dart';

class ProjectTasksTab extends ConsumerWidget {
  const ProjectTasksTab({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(projectAiTasksProvider(projectId));

    return tasksAsync.when(
      loading: () => const LoadingIndicator(message: '加载 AI 任务...'),
      error: (e, _) => Center(
        child: InfoBar(
          title: const Text('加载失败'),
          content: Text('$e'),
          severity: InfoBarSeverity.error,
        ),
      ),
      data: (tasks) {
        if (tasks.isEmpty) {
          return const EmptyState(
            icon: FluentIcons.processing,
            title: '暂无 AI 任务',
            description: '使用 AI 功能时关联此项目，任务记录将显示在这里',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          itemCount: tasks.length,
          itemBuilder: (context, index) =>
              _AiTaskListItem(task: tasks[index]),
        );
      },
    );
  }
}

class _AiTaskListItem extends StatelessWidget {
  const _AiTaskListItem({required this.task});

  final AiTask task;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final createdAt = DateTime.fromMillisecondsSinceEpoch(task.createdAt);
    final dateStr = formatDateTime(createdAt);
    final typeColor = _typeColor(task.type, theme.brightness);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Card(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                _typeIcon(task.type),
                size: 14,
                color: typeColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        _typeLabel(task.type),
                        style: theme.typography.body?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusBadge(status: task.status),
                    ],
                  ),
                  if (task.inputPrompt != null &&
                      task.inputPrompt!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      task.inputPrompt!,
                      style: theme.typography.caption?.copyWith(
                        color: theme.resources.textFillColorSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (task.model != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  task.model!,
                  style: theme.typography.caption?.copyWith(
                    color: theme.resources.textFillColorSecondary,
                  ),
                ),
              ),
            if (task.tokenUsage != null && task.tokenUsage! > 0)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      FluentIcons.diagnostic,
                      size: 12,
                      color: theme.resources.textFillColorTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${task.tokenUsage}',
                      style: theme.typography.caption?.copyWith(
                        color: theme.resources.textFillColorTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              dateStr,
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _typeIcon(String type) => switch (type) {
        'chat' => FluentIcons.chat,
        'image_gen' => FluentIcons.image_search,
        'video_gen' => FluentIcons.video,
        _ => FluentIcons.processing,
      };

  static String _typeLabel(String type) => switch (type) {
        'chat' => 'AI 对话',
        'image_gen' => '图片生成',
        'video_gen' => '视频生成',
        _ => 'AI 任务',
      };

  Color _typeColor(String type, Brightness brightness) => switch (type) {
        'chat' => AppColors.chat(brightness),
        'image_gen' => AppColors.imageGen(brightness),
        'video_gen' => AppColors.videoGen(brightness),
        _ => AppColors.warning(brightness),
      };
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final b = theme.brightness;
    final (label, color) = switch (status) {
      'pending' => ('等待中', AppColors.pending(b)),
      'running' => ('进行中', AppColors.info(b)),
      'completed' => ('已完成', AppColors.success(b)),
      'failed' => ('失败', AppColors.error(b)),
      'cancelled' => ('已取消', AppColors.pending(b)),
      _ => (status, AppColors.pending(b)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
