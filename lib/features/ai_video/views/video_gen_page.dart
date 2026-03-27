import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/platform_utils.dart';
import '../providers/video_gen_provider.dart';
import '../widgets/video_gen_params_panel.dart';
import '../widgets/video_gen_result_area.dart';
import '../widgets/video_gen_task_queue.dart';

class VideoGenPage extends ConsumerStatefulWidget {
  const VideoGenPage({super.key});

  @override
  ConsumerState<VideoGenPage> createState() => _VideoGenPageState();
}

class _VideoGenPageState extends ConsumerState<VideoGenPage> {
  int _mobileTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isQueueCollapsed = ref.watch(
      videoGenProvider.select((s) => s.isQueueCollapsed),
    );

    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth <= Breakpoints.tablet) {
            return _buildMobileLayout(context, isQueueCollapsed);
          }
          return _buildDesktopLayout(context, isQueueCollapsed);
        },
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, bool isQueueCollapsed) {
    return Column(
      children: [
        _buildToolbar(context),
        const Divider(),
        const Expanded(
          flex: 7,
          child: Row(
            children: [
              SizedBox(width: 380, child: VideoGenParamsPanel()),
              Divider(direction: Axis.vertical),
              Expanded(child: VideoGenResultArea()),
            ],
          ),
        ),
        if (!isQueueCollapsed) ...[
          const Divider(),
          const SizedBox(height: 250, child: VideoGenTaskQueue()),
        ],
        if (isQueueCollapsed) _buildCollapsedQueueBar(context),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context, bool isQueueCollapsed) {
    return Column(
      children: [
        _buildMobileToolbar(context),
        const Divider(),
        Expanded(
          child: _mobileTabIndex == 0
              ? const SingleChildScrollView(child: VideoGenParamsPanel())
              : const VideoGenResultArea(),
        ),
        if (!isQueueCollapsed) ...[
          const Divider(),
          const SizedBox(height: 180, child: VideoGenTaskQueue()),
        ],
        if (isQueueCollapsed) _buildCollapsedQueueBar(context),
      ],
    );
  }

  Widget _buildMobileToolbar(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(FluentIcons.video, size: 18, color: theme.accentColor),
          const SizedBox(width: 6),
          Text('视频生成', style: theme.typography.bodyStrong),
          const Spacer(),
          ToggleButton(
            checked: _mobileTabIndex == 0,
            onChanged: (_) => setState(() => _mobileTabIndex = 0),
            child: const Text('参数'),
          ),
          const SizedBox(width: 4),
          ToggleButton(
            checked: _mobileTabIndex == 1,
            onChanged: (_) => setState(() => _mobileTabIndex = 1),
            child: const Text('结果'),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(FluentIcons.video, size: 20, color: theme.accentColor),
          const SizedBox(width: 8),
          Text('AI 视频生成', style: theme.typography.subtitle),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildCollapsedQueueBar(BuildContext context) {
    final theme = FluentTheme.of(context);
    final historyAsync = ref.watch(videoGenHistoryProvider);
    final activeCount =
        historyAsync.whenOrNull(
          data: (tasks) => tasks
              .where((t) => t.status == 'running' || t.status == 'pending')
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
              Icon(
                FluentIcons.task_list,
                size: 14,
                color: theme.resources.textFillColorSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                '任务队列${activeCount > 0 ? ' ($activeCount 进行中)' : ''}',
                style: theme.typography.caption,
              ),
              const Spacer(),
              Icon(
                FluentIcons.chevron_up,
                size: 10,
                color: theme.resources.textFillColorSecondary,
              ),
            ],
          ),
        );
      },
    );
  }
}
