import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/ai_providers.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/services/notification_service.dart';
import 'video_gen_provider.dart';

// ---------------------------------------------------------------------------
// Poll task descriptor
// ---------------------------------------------------------------------------

class PollTask {
  final String localTaskId;
  final String remoteTaskId;
  final String providerId;
  final DateTime startedAt;

  const PollTask({
    required this.localTaskId,
    required this.remoteTaskId,
    required this.providerId,
    required this.startedAt,
  });
}

// ---------------------------------------------------------------------------
// Poller state
// ---------------------------------------------------------------------------

class VideoPollerState {
  final Map<String, PollTask> activeTasks;

  const VideoPollerState({this.activeTasks = const {}});

  VideoPollerState copyWith({Map<String, PollTask>? activeTasks}) {
    return VideoPollerState(
      activeTasks: activeTasks ?? this.activeTasks,
    );
  }
}

// ---------------------------------------------------------------------------
// Poller notifier
// ---------------------------------------------------------------------------

final videoTaskPollerProvider =
    NotifierProvider<VideoTaskPoller, VideoPollerState>(VideoTaskPoller.new);

class VideoTaskPoller extends Notifier<VideoPollerState> {
  static final _log = Logger(printer: PrettyPrinter(methodCount: 0));
  static const _pollInterval = Duration(seconds: 5);

  Timer? _timer;

  @override
  VideoPollerState build() {
    ref
      ..keepAlive()
      ..onDispose(_stopTimer);
    _restorePolling();
    return const VideoPollerState();
  }

  void startPolling({
    required String localTaskId,
    required String remoteTaskId,
    required String providerId,
  }) {
    final task = PollTask(
      localTaskId: localTaskId,
      remoteTaskId: remoteTaskId,
      providerId: providerId,
      startedAt: DateTime.now(),
    );

    final updated = Map<String, PollTask>.from(state.activeTasks);
    updated[localTaskId] = task;
    state = state.copyWith(activeTasks: updated);

    _ensureTimerRunning();
    _log.i('[Poller] Started polling for task $localTaskId '
        '(remote: $remoteTaskId)');
  }

  void cancelPolling(String localTaskId) {
    final updated = Map<String, PollTask>.from(state.activeTasks)
      ..remove(localTaskId);
    state = state.copyWith(activeTasks: updated);

    if (updated.isEmpty) _stopTimer();
    _log.i('[Poller] Cancelled polling for task $localTaskId');
  }

  /// Restore polling for tasks that were running when the app was closed.
  Future<void> _restorePolling() async {
    try {
      final dao = ref.read(aiTaskDaoProvider);
      final runningTasks = await dao.filterByStatus('running');
      final videoTasks = runningTasks.where((t) => t.type == 'video');

      for (final task in videoTasks) {
        if (task.inputParams == null) continue;
        try {
          final params =
              jsonDecode(task.inputParams!) as Map<String, dynamic>;
          final remoteTaskId = params['remote_task_id'] as String?;
          if (remoteTaskId == null) continue;

          // We need to figure out providerId - look up from the manager
          final manager =
              await ref.read(aiServicesReadyProvider.future);
          final services = manager.getVideoServices();
          final service = services
              .where((s) => s.providerName == task.provider)
              .firstOrNull;
          if (service == null) continue;

          startPolling(
            localTaskId: task.id,
            remoteTaskId: remoteTaskId,
            providerId: service.providerId,
          );
        } catch (_) {
          continue;
        }
      }
    } catch (e) {
      _log.e('[Poller] Failed to restore polling: $e');
    }
  }

  void _ensureTimerRunning() {
    if (_timer != null && _timer!.isActive) return;
    _timer = Timer.periodic(_pollInterval, (_) => _pollAll());
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _pollAll() async {
    if (state.activeTasks.isEmpty) {
      _stopTimer();
      return;
    }

    final tasks = List<PollTask>.from(state.activeTasks.values);

    await Future.wait(
      tasks.map((task) => _pollSingle(task).catchError((e) {
        _log.e('[Poller] Error polling task ${task.localTaskId}: $e');
      })),
    );
  }

  Future<void> _pollSingle(PollTask task) async {
    final manager = ref.read(aiServiceManagerProvider);
    final service = manager.getService(task.providerId);
    if (service == null) {
      _log.w('[Poller] Service not found for ${task.providerId}, '
          'removing task ${task.localTaskId}');
      cancelPolling(task.localTaskId);
      return;
    }

    final response = await service.checkVideoStatus(task.remoteTaskId);
    final dao = ref.read(aiTaskDaoProvider);

    if (response.status == 'completed' && response.videoUrl != null) {
      await dao.updateTaskFields(task.localTaskId, AiTasksCompanion(
        status: const Value('completed'),
        outputText: Value(jsonEncode(response.toJson())),
        completedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ));

      cancelPolling(task.localTaskId);

      ref.read(videoGenProvider.notifier)
          .viewTaskResult(task.localTaskId, response.videoUrl);
      ref.invalidate(videoGenTaskDetailProvider(task.localTaskId));

      ref.read(notificationServiceProvider).show(
        title: '视频生成完成',
        message: '您的视频已生成完毕，点击查看结果',
      );

      _log.i('[Poller] Task ${task.localTaskId} completed');
    } else if (response.status == 'failed') {
      await dao.updateTaskFields(task.localTaskId, AiTasksCompanion(
        status: const Value('failed'),
        errorMessage: const Value('视频生成失败'),
        completedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ));

      cancelPolling(task.localTaskId);
      ref.invalidate(videoGenTaskDetailProvider(task.localTaskId));

      ref.read(notificationServiceProvider).show(
        title: '视频生成失败',
        message: '视频生成任务失败，请重试',
        isError: true,
      );

      _log.e('[Poller] Task ${task.localTaskId} failed');
    }
    // Otherwise still processing – wait for next poll cycle
  }
}
