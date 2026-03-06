import 'dart:convert';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/ai/ai_models.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../providers/image_gen_provider.dart';

class ImageGenHistory extends ConsumerWidget {
  const ImageGenHistory({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(imageGenHistoryProvider);

    return historyAsync.when(
      loading: () => const LoadingIndicator(message: '加载历史记录...'),
      error: (e, _) => EmptyState(
        icon: FluentIcons.error_badge,
        title: '加载失败',
        description: e.toString(),
      ),
      data: (tasks) {
        if (tasks.isEmpty) {
          return const EmptyState(
            icon: FluentIcons.history,
            title: '暂无生成记录',
            description: '生成的图片记录将显示在这里',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: tasks.length,
          itemBuilder: (ctx, i) => _HistoryCard(task: tasks[i]),
        );
      },
    );
  }
}

class _HistoryCard extends ConsumerStatefulWidget {
  const _HistoryCard({required this.task});
  final AiTask task;

  @override
  ConsumerState<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends ConsumerState<_HistoryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final task = widget.task;
    final time = DateTime.fromMillisecondsSinceEpoch(task.createdAt);
    final formattedTime = DateFormat('yyyy-MM-dd HH:mm').format(time);
    final isFailed = task.status == 'failed';
    final isCompleted = task.status == 'completed';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: _statusIcon(task.status, theme),
              title: Text(
                task.inputPrompt ?? '(无提示词)',
                maxLines: _expanded ? 10 : 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '$formattedTime · ${task.provider} · ${task.model ?? ""}',
                style: theme.typography.caption?.copyWith(
                  color: theme.resources.textFillColorSecondary,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isFailed)
                    Tooltip(
                      message: '重试',
                      child: IconButton(
                        icon: const Icon(FluentIcons.refresh, size: 14),
                        onPressed: () => ref
                            .read(imageGenProvider.notifier)
                            .retryFromTask(task),
                      ),
                    ),
                  IconButton(
                    icon: Icon(
                      _expanded
                          ? FluentIcons.chevron_up
                          : FluentIcons.chevron_down,
                      size: 12,
                    ),
                    onPressed: () => setState(() => _expanded = !_expanded),
                  ),
                ],
              ),
              onPressed: () => setState(() => _expanded = !_expanded),
            ),
            if (_expanded) ...[
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isFailed && task.errorMessage != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          task.errorMessage!,
                          style: theme.typography.caption?.copyWith(
                            color: Colors.red.normal,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (task.inputParams != null) ...[
                      Text('参数', style: theme.typography.bodyStrong),
                      const SizedBox(height: 4),
                      Text(
                        _formatParams(task.inputParams!),
                        style: theme.typography.caption,
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (isCompleted && task.outputText != null)
                      _buildOutputImages(context, task.outputText!),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusIcon(String status, FluentThemeData theme) {
    switch (status) {
      case 'completed':
        return Icon(FluentIcons.completed_solid,
            size: 16, color: Colors.green.normal);
      case 'failed':
        return Icon(FluentIcons.error_badge, size: 16, color: Colors.red.normal);
      case 'running':
        return const SizedBox(
          width: 16,
          height: 16,
          child: ProgressRing(strokeWidth: 2),
        );
      default:
        return Icon(FluentIcons.clock,
            size: 16, color: theme.resources.textFillColorSecondary);
    }
  }

  String _formatParams(String paramsJson) {
    try {
      final params = jsonDecode(paramsJson) as Map<String, dynamic>;
      return params.entries
          .map((e) => '${e.key}: ${e.value}')
          .join(' · ');
    } catch (_) {
      return paramsJson;
    }
  }

  Widget _buildOutputImages(BuildContext context, String outputJson) {
    try {
      final json = jsonDecode(outputJson) as Map<String, dynamic>;
      final response = AiImageResponse.fromJson(json);
      if (response.images.isEmpty) return const SizedBox.shrink();

      return SizedBox(
        height: 120,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: response.images.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final img = response.images[i];
            return Container(
              width: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: FluentTheme.of(context)
                      .resources
                      .cardStrokeColorDefault,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildThumbnail(img),
            );
          },
        ),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildThumbnail(AiGeneratedImage image) {
    if (image.bytes != null) {
      return Image.memory(
        image.bytes!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Center(child: Icon(FluentIcons.photo2)),
      );
    }
    if (image.url != null) {
      return Image.network(
        image.url!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Center(child: Icon(FluentIcons.photo2)),
      );
    }
    return const Center(child: Icon(FluentIcons.photo2));
  }
}
