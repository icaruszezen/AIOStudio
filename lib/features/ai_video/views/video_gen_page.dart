import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/video_gen_provider.dart';
import '../widgets/video_gen_params_panel.dart';
import '../widgets/video_gen_result_area.dart';
import '../widgets/video_gen_task_queue.dart';

class VideoGenPage extends ConsumerWidget {
  const VideoGenPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isQueueCollapsed = ref.watch(
      videoGenProvider.select((s) => s.isQueueCollapsed),
    );

    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: Column(
        children: [
          _buildToolbar(context, ref),
          const Divider(),
          // Upper region: params + result (~70%)
          const Expanded(
            flex: 7,
            child: Row(
              children: [
                SizedBox(
                  width: 380,
                  child: VideoGenParamsPanel(),
                ),
                Divider(direction: Axis.vertical),
                Expanded(child: VideoGenResultArea()),
              ],
            ),
          ),
          // Lower region: task queue (~30%, collapsible)
          if (!isQueueCollapsed) ...[
            const Divider(),
            const SizedBox(
              height: 250,
              child: VideoGenTaskQueue(),
            ),
          ],
          if (isQueueCollapsed) _buildCollapsedQueueBar(context, ref),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            FluentIcons.video,
            size: 20,
            color: theme.accentColor,
          ),
          const SizedBox(width: 8),
          Text('AI 视频生成', style: theme.typography.subtitle),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildCollapsedQueueBar(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final historyAsync = ref.watch(videoGenHistoryProvider);
    final activeCount = historyAsync.whenOrNull(
          data: (tasks) =>
              tasks.where((t) => t.status == 'running' || t.status == 'pending')
                  .length,
        ) ??
        0;

    return HoverButton(
      onPressed: () => ref.read(videoGenProvider.notifier).toggleQueue(),
      builder: (context, states) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: states.contains(WidgetState.hovered)
                ? theme.resources.subtleFillColorSecondary
                : null,
            border: Border(
              top: BorderSide(color: theme.resources.cardStrokeColorDefault),
            ),
          ),
          child: Row(
            children: [
              Icon(FluentIcons.task_list, size: 14,
                  color: theme.resources.textFillColorSecondary),
              const SizedBox(width: 6),
              Text(
                '任务队列${activeCount > 0 ? ' ($activeCount 进行中)' : ''}',
                style: theme.typography.caption,
              ),
              const Spacer(),
              Icon(FluentIcons.chevron_up, size: 10,
                  color: theme.resources.textFillColorSecondary),
            ],
          ),
        );
      },
    );
  }
}
