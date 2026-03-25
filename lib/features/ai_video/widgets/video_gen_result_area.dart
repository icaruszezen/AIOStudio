import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_state.dart';
import '../../ai_image/widgets/save_to_asset_dialog.dart';
import '../../assets/widgets/video_player_widget.dart';
import '../providers/video_gen_provider.dart';
import '../providers/video_task_poller.dart';

class VideoGenResultArea extends ConsumerStatefulWidget {
  const VideoGenResultArea({super.key});

  @override
  ConsumerState<VideoGenResultArea> createState() => _VideoGenResultAreaState();
}

class _VideoGenResultAreaState extends ConsumerState<VideoGenResultArea> {
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 10),
  ));
  Timer? _elapsedTimer;
  Duration _elapsed = Duration.zero;
  DateTime? _startTime;

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _dio.close();
    super.dispose();
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _startTime = DateTime.now();
    _elapsed = Duration.zero;
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _startTime != null) {
        setState(() {
          _elapsed = DateTime.now().difference(_startTime!);
        });
      }
    });
  }

  void _stopElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final taskId = ref.watch(
      videoGenProvider.select((s) => s.currentViewingTaskId),
    );
    final isSubmitting = ref.watch(
      videoGenProvider.select((s) => s.isSubmitting),
    );
    final errorMessage = ref.watch(
      videoGenProvider.select((s) => s.errorMessage),
    );
    final activeTasks = ref.watch(
      videoTaskPollerProvider.select((s) => s.activeTasks),
    );

    if (isSubmitting) {
      return _buildSubmittingState(context);
    }

    if (errorMessage != null && taskId == null) {
      return ErrorState(title: '生成失败', message: errorMessage);
    }

    if (taskId == null) {
      return const EmptyState(
        icon: FluentIcons.video,
        title: '开始创作',
        description: '在左侧设置参数并点击"开始生成"',
      );
    }

    // Check if this task is still being polled
    final isPolling = activeTasks.containsKey(taskId);

    if (isPolling) {
      if (_elapsedTimer == null || !_elapsedTimer!.isActive) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _startElapsedTimer();
        });
      }
      return _buildPollingState(context, taskId);
    }

    _stopElapsedTimer();

    final genState = ref.watch(videoGenProvider);

    // Task finished – check for video
    if (genState.currentVideoPath != null) {
      return _buildVideoResult(context, genState);
    }

    // Load task from DB to check result
    final taskAsync = ref.watch(videoGenTaskDetailProvider(taskId));
    return taskAsync.when(
      loading: () => _buildPollingState(context, taskId),
      error: (e, _) => ErrorState(title: '生成失败', message: e.toString()),
      data: (task) {
        if (task == null) {
          return const EmptyState(
            icon: FluentIcons.video,
            title: '任务未找到',
          );
        }

        if (task.status == 'failed') {
          return ErrorState(
            title: '生成失败',
            message: task.errorMessage ?? '视频生成失败',
          );
        }

        if (task.status == 'completed' && task.outputText != null) {
          try {
            final json =
                jsonDecode(task.outputText!) as Map<String, dynamic>;
            final videoUrl = json['video_url'] as String?;
            if (videoUrl != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref.read(videoGenProvider.notifier)
                    .viewTaskResult(taskId, videoUrl);
              });
              return _buildVideoResult(
                context,
                genState.copyWith(currentVideoPath: videoUrl),
              );
            }
          } catch (_) {}
        }

        if (task.status == 'running' || task.status == 'pending') {
          return _buildPollingState(context, taskId);
        }

        return const EmptyState(
          icon: FluentIcons.video,
          title: '等待结果...',
        );
      },
    );
  }

  Widget _buildSubmittingState(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ProgressRing(),
          const SizedBox(height: 16),
          Text('正在提交生成任务...', style: theme.typography.body),
        ],
      ),
    );
  }

  Widget _buildPollingState(BuildContext context, String taskId) {
    final theme = FluentTheme.of(context);
    final minutes = _elapsed.inMinutes;
    final seconds = _elapsed.inSeconds % 60;
    final elapsedStr =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ProgressRing(strokeWidth: 4),
            const SizedBox(height: 24),
            Text('视频生成中...', style: theme.typography.subtitle),
            const SizedBox(height: 8),
            Text(
              '已用时 $elapsedStr',
              style: theme.typography.body?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '视频生成通常需要数分钟，请耐心等待',
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Button(
              onPressed: () {
                ref.read(videoTaskPollerProvider.notifier)
                    .cancelPolling(taskId, markCancelled: true);
                ref.read(videoGenProvider.notifier).clearViewingTask();
              },
              child: const Text('取消'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoResult(BuildContext context, VideoGenState genState) {
    final theme = FluentTheme.of(context);
    final videoPath = genState.currentVideoPath!;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.resources.cardStrokeColorDefault,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: VideoPlayerWidget(filePath: videoPath),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton(
                onPressed: () => _saveToAsset(context),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.save, size: 14),
                    SizedBox(width: 6),
                    Text('保存到资产'),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Button(
                onPressed: () => _saveAs(context, videoPath),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.download, size: 14),
                    SizedBox(width: 6),
                    Text('另存为'),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Button(
                onPressed: () =>
                    ref.read(videoGenProvider.notifier).clearViewingTask(),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.refresh, size: 14),
                    SizedBox(width: 6),
                    Text('重新生成'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _saveToAsset(BuildContext context) async {
    final genState = ref.read(videoGenProvider);
    final taskId = genState.currentViewingTaskId;
    if (taskId == null) return;

    final result = await showDialog<SaveToAssetResult>(
      context: context,
      builder: (_) => SaveToAssetDialog(
        defaultName: genState.prompt.length > 20
            ? genState.prompt.substring(0, 20)
            : genState.prompt,
      ),
    );

    if (result != null && context.mounted) {
      final asset = await ref.read(videoGenProvider.notifier).saveToAsset(
            taskId: taskId,
            projectId: result.projectId,
            name: result.name,
          );
      if (context.mounted) {
        await displayInfoBar(context, builder: (ctx, close) {
          return InfoBar(
            title: Text(asset != null ? '已保存到资产库' : '保存失败'),
            severity:
                asset != null ? InfoBarSeverity.success : InfoBarSeverity.error,
            onClose: close,
          );
        });
      }
    }
  }

  Future<void> _saveAs(BuildContext context, String videoUrl) async {
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: '另存为',
      fileName: 'generated_video.mp4',
    );
    if (outputPath == null) return;

    try {
      final ext = p.extension(outputPath).toLowerCase();
      final savePath = ext.isEmpty ? '$outputPath.mp4' : outputPath;

      if (videoUrl.startsWith('http')) {
        await _dio.download(videoUrl, savePath);
      } else {
        await File(videoUrl).copy(savePath);
      }

      if (context.mounted) {
        await displayInfoBar(context, builder: (ctx, close) {
          return InfoBar(
            title: const Text('文件已保存'),
            severity: InfoBarSeverity.success,
            onClose: close,
          );
        });
      }
    } catch (e) {
      if (context.mounted) {
        await displayInfoBar(context, builder: (ctx, close) {
          return InfoBar(
            title: Text('保存失败: $e'),
            severity: InfoBarSeverity.error,
            onClose: close,
          );
        });
      }
    }
  }
}
