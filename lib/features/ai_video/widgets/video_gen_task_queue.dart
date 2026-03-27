import 'dart:convert';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/error_utils.dart';
import '../../../shared/utils/format_utils.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../providers/video_gen_provider.dart';
import '../providers/video_task_poller.dart';

class VideoGenTaskQueue extends ConsumerWidget {
  const VideoGenTaskQueue({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final historyAsync = ref.watch(videoGenHistoryProvider);

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Icon(FluentIcons.task_list, size: 14, color: theme.accentColor),
              const SizedBox(width: 6),
              historyAsync.when(
                loading: () => Text('任务队列', style: theme.typography.bodyStrong),
                error: (_, __) =>
                    Text('任务队列', style: theme.typography.bodyStrong),
                data: (tasks) => Text(
                  '任务队列 (${tasks.length})',
                  style: theme.typography.bodyStrong,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(FluentIcons.chevron_down, size: 10),
                onPressed: () =>
                    ref.read(videoGenProvider.notifier).toggleQueue(),
              ),
            ],
          ),
        ),
        const Divider(),
        // Task list
        Expanded(
          child: historyAsync.when(
            loading: () => const LoadingIndicator(message: '加载任务记录...'),
            error: (e, _) => EmptyState(
              icon: FluentIcons.error_badge,
              title: '加载失败',
              description: formatUserError(e),
            ),
            data: (tasks) {
              if (tasks.isEmpty) {
                return const EmptyState(
                  icon: FluentIcons.task_list,
                  title: '暂无任务',
                  description: '生成的视频任务将显示在这里',
                );
              }
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(12),
                itemCount: tasks.length,
                itemBuilder: (ctx, i) => _TaskCard(task: tasks[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TaskCard extends ConsumerWidget {
  const _TaskCard({required this.task});
  final AiTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final pollerState = ref.watch(videoTaskPollerProvider);
    final isPolling = pollerState.activeTasks.containsKey(task.id);
    final time = DateTime.fromMillisecondsSinceEpoch(task.createdAt);
    final formattedTime = formatCompactDateTime(time);

    final statusColor = _statusColor(task.status, theme.brightness);
    final statusText = _statusText(task.status, isPolling);

    String elapsedText = '';
    if (task.startedAt != null) {
      final start = DateTime.fromMillisecondsSinceEpoch(task.startedAt!);
      final end = task.completedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(task.completedAt!)
          : DateTime.now();
      final diff = end.difference(start);
      final m = diff.inMinutes;
      final s = diff.inSeconds % 60;
      elapsedText = '${m}m ${s}s';
    }

    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 10),
      child: Card(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status indicator
            Row(
              children: [
                _buildStatusIcon(task.status, isPolling, theme),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    statusText,
                    style: theme.typography.caption?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Prompt summary
            Expanded(
              child: Text(
                task.inputPrompt ?? '(无提示词)',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.body,
              ),
            ),
            const SizedBox(height: 6),
            // Time & duration
            Text(
              '$formattedTime${elapsedText.isNotEmpty ? ' · $elapsedText' : ''}',
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (task.status == 'completed')
                  _actionButton(
                    context,
                    icon: FluentIcons.play,
                    tooltip: '查看结果',
                    onPressed: () => _viewResult(ref, task),
                  ),
                if (task.status == 'failed') ...[
                  _actionButton(
                    context,
                    icon: FluentIcons.refresh,
                    tooltip: '重试',
                    onPressed: () =>
                        ref.read(videoGenProvider.notifier).retryFromTask(task),
                  ),
                  if (task.errorMessage != null)
                    _actionButton(
                      context,
                      icon: FluentIcons.info,
                      tooltip: task.errorMessage!,
                      onPressed: () => _showError(context, task.errorMessage!),
                    ),
                ],
                if (isPolling)
                  _actionButton(
                    context,
                    icon: FluentIcons.cancel,
                    tooltip: '取消',
                    onPressed: () => ref
                        .read(videoTaskPollerProvider.notifier)
                        .cancelPolling(task.id, markCancelled: true),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(
    String status,
    bool isPolling,
    FluentThemeData theme,
  ) {
    switch (status) {
      case 'completed':
        return Icon(
          FluentIcons.completed_solid,
          size: 14,
          color: AppColors.success(theme.brightness),
        );
      case 'failed':
        return Icon(
          FluentIcons.error_badge,
          size: 14,
          color: AppColors.error(theme.brightness),
        );
      case 'running':
        return const SizedBox(
          width: 14,
          height: 14,
          child: ProgressRing(strokeWidth: 2),
        );
      default:
        return Icon(
          FluentIcons.clock,
          size: 14,
          color: AppColors.pending(theme.brightness),
        );
    }
  }

  Color _statusColor(String status, Brightness brightness) {
    switch (status) {
      case 'completed':
        return AppColors.success(brightness);
      case 'failed':
        return AppColors.error(brightness);
      case 'running':
        return AppColors.info(brightness);
      default:
        return AppColors.pending(brightness);
    }
  }

  String _statusText(String status, bool isPolling) {
    switch (status) {
      case 'completed':
        return '已完成';
      case 'failed':
        return '失败';
      case 'running':
        return isPolling ? '生成中...' : '运行中';
      case 'pending':
        return '等待中';
      default:
        return status;
    }
  }

  Widget _actionButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    VoidCallback? onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: IconButton(icon: Icon(icon, size: 12), onPressed: onPressed),
      ),
    );
  }

  void _viewResult(WidgetRef ref, AiTask task) {
    if (task.outputText == null) return;
    try {
      final json = jsonDecode(task.outputText!) as Map<String, dynamic>;
      final videoUrl = json['video_url'] as String?;
      if (videoUrl != null) {
        ref.read(videoGenProvider.notifier).viewTaskResult(task.id, videoUrl);
      }
    } catch (_) {}
  }

  void _showError(BuildContext context, String error) {
    showDialog(
      context: context,
      builder: (_) => ContentDialog(
        title: const Text('错误详情'),
        content: SelectableText(error),
        actions: [
          Button(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
