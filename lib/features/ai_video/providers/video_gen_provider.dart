import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/ai_providers.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/services/ai/ai_models.dart';
import '../../../core/services/ai/ai_service.dart';
import '../../../core/services/ai/ai_service_manager.dart';
import '../../../shared/utils/error_utils.dart';
import 'video_task_poller.dart';

// ---------------------------------------------------------------------------
// Enums & presets
// ---------------------------------------------------------------------------

enum VideoGenMode { text2video, image2video }

class VideoResolution {
  final String label;
  final int width;
  final int height;

  const VideoResolution(this.label, this.width, this.height);
}

const videoResolutions = [
  VideoResolution('1280 × 720 (720p)', 1280, 720),
  VideoResolution('1920 × 1080 (1080p)', 1920, 1080),
  VideoResolution('720 × 720', 720, 720),
  VideoResolution('1080 × 1080', 1080, 1080),
  VideoResolution('720 × 1280', 720, 1280),
];

const videoDurations = [3, 5, 10];

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class VideoGenState {
  final VideoGenMode mode;
  final String? selectedProviderId;
  final String? selectedModel;
  final String prompt;
  final String? inputImagePath;
  final int width;
  final int height;
  final int duration;
  final int selectedResolutionIndex;
  final String? currentViewingTaskId;
  final String? currentVideoPath;
  final String? errorMessage;
  final bool isQueueCollapsed;
  final bool isSubmitting;

  const VideoGenState({
    this.mode = VideoGenMode.text2video,
    this.selectedProviderId,
    this.selectedModel,
    this.prompt = '',
    this.inputImagePath,
    this.width = 1280,
    this.height = 720,
    this.duration = 5,
    this.selectedResolutionIndex = 0,
    this.currentViewingTaskId,
    this.currentVideoPath,
    this.errorMessage,
    this.isQueueCollapsed = false,
    this.isSubmitting = false,
  });

  VideoGenState copyWith({
    VideoGenMode? mode,
    String? selectedProviderId,
    String? selectedModel,
    String? prompt,
    String? inputImagePath,
    int? width,
    int? height,
    int? duration,
    int? selectedResolutionIndex,
    String? currentViewingTaskId,
    String? currentVideoPath,
    String? errorMessage,
    bool? isQueueCollapsed,
    bool? isSubmitting,
    bool clearProvider = false,
    bool clearModel = false,
    bool clearInputImage = false,
    bool clearViewingTask = false,
    bool clearVideoPath = false,
    bool clearError = false,
  }) {
    return VideoGenState(
      mode: mode ?? this.mode,
      selectedProviderId: clearProvider
          ? null
          : (selectedProviderId ?? this.selectedProviderId),
      selectedModel: clearModel ? null : (selectedModel ?? this.selectedModel),
      prompt: prompt ?? this.prompt,
      inputImagePath: clearInputImage
          ? null
          : (inputImagePath ?? this.inputImagePath),
      width: width ?? this.width,
      height: height ?? this.height,
      duration: duration ?? this.duration,
      selectedResolutionIndex:
          selectedResolutionIndex ?? this.selectedResolutionIndex,
      currentViewingTaskId: clearViewingTask
          ? null
          : (currentViewingTaskId ?? this.currentViewingTaskId),
      currentVideoPath: clearVideoPath
          ? null
          : (currentVideoPath ?? this.currentVideoPath),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isQueueCollapsed: isQueueCollapsed ?? this.isQueueCollapsed,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

final videoGenProvider = NotifierProvider<VideoGenNotifier, VideoGenState>(
  VideoGenNotifier.new,
);

class VideoGenNotifier extends Notifier<VideoGenState> {
  static final _log = Logger(printer: PrettyPrinter(methodCount: 0));
  static const _uuid = Uuid();

  AiServiceManager get _serviceManager => ref.read(aiServiceManagerProvider);

  @override
  VideoGenState build() {
    _initDefaultProvider();
    return const VideoGenState();
  }

  Future<void> _initDefaultProvider() async {
    final manager = await ref.read(aiServicesReadyProvider.future);
    if (state.selectedProviderId != null) return;
    final videoServices = manager.getVideoServices();
    if (videoServices.isNotEmpty) {
      final service = videoServices.first;
      final models = service.videoModels;
      state = state.copyWith(
        selectedProviderId: service.providerId,
        selectedModel: models.isNotEmpty ? models.first : null,
      );
    }
  }

  // -- Mode -----------------------------------------------------------------

  void setMode(VideoGenMode mode) {
    state = state.copyWith(mode: mode, clearError: true);
  }

  // -- Provider / Model selection -------------------------------------------

  void selectProvider(String providerId) {
    final service = _serviceManager.getService(providerId);
    if (service == null) return;
    final models = service.videoModels;
    state = state.copyWith(
      selectedProviderId: providerId,
      selectedModel: models.isNotEmpty ? models.first : null,
    );
  }

  void selectModel(String model) {
    state = state.copyWith(selectedModel: model);
  }

  List<AiService> getAvailableProviders() {
    return _serviceManager.getVideoServices();
  }

  List<String> getProviderVideoModels(String providerId) {
    final service = _serviceManager.getService(providerId);
    return service?.videoModels ?? [];
  }

  // -- Prompt / Image -------------------------------------------------------

  void updatePrompt(String text) =>
      state = state.copyWith(prompt: text, clearError: true);

  void setInputImage(String? path) {
    if (path == null) {
      state = state.copyWith(clearInputImage: true);
    } else {
      state = state.copyWith(inputImagePath: path);
    }
  }

  // -- Resolution / Duration ------------------------------------------------

  void selectResolution(int index) {
    if (index < 0 || index >= videoResolutions.length) return;
    final res = videoResolutions[index];
    state = state.copyWith(
      selectedResolutionIndex: index,
      width: res.width,
      height: res.height,
    );
  }

  void setDuration(int seconds) => state = state.copyWith(duration: seconds);

  // -- Queue ----------------------------------------------------------------

  void toggleQueue() =>
      state = state.copyWith(isQueueCollapsed: !state.isQueueCollapsed);

  // -- View task result -----------------------------------------------------

  void viewTaskResult(String taskId, String? videoPath) {
    state = state.copyWith(
      currentViewingTaskId: taskId,
      currentVideoPath: videoPath,
      clearError: true,
    );
  }

  void clearViewingTask() {
    state = state.copyWith(clearViewingTask: true, clearVideoPath: true);
  }

  // -- Submit ---------------------------------------------------------------

  Future<void> submitGeneration() async {
    if (state.isSubmitting) return;
    if (state.prompt.trim().isEmpty && state.mode == VideoGenMode.text2video) {
      return;
    }
    if (state.mode == VideoGenMode.image2video &&
        state.inputImagePath == null) {
      return;
    }
    if (state.selectedProviderId == null || state.selectedModel == null) return;

    final service = _serviceManager.getService(state.selectedProviderId!);
    if (service == null) return;

    final dao = ref.read(aiTaskDaoProvider);
    final taskId = _uuid.v4();
    final now = DateTime.now();

    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      currentViewingTaskId: taskId,
      clearVideoPath: true,
    );

    final inputParams = jsonEncode({
      'mode': state.mode.name,
      'width': state.width,
      'height': state.height,
      'duration': state.duration,
      if (state.inputImagePath != null) 'input_image': state.inputImagePath,
    });

    await dao.insertTask(
      AiTasksCompanion.insert(
        id: taskId,
        type: 'video',
        status: 'pending',
        provider: service.providerName,
        model: Value(state.selectedModel),
        inputPrompt: Value(state.prompt),
        inputParams: Value(inputParams),
        createdAt: now.millisecondsSinceEpoch,
      ),
    );

    await dao.updateTaskFields(
      taskId,
      AiTasksCompanion(
        status: const Value('running'),
        startedAt: Value(now.millisecondsSinceEpoch),
      ),
    );

    try {
      final request = AiVideoRequest(
        prompt: state.prompt,
        model: state.selectedModel!,
        width: state.width,
        height: state.height,
        duration: state.duration,
        imageUrl: state.mode == VideoGenMode.image2video
            ? state.inputImagePath
            : null,
      );

      final response = await service.generateVideo(request);

      final remoteTaskId = response.taskId;

      // Store remote task id in inputParams for recovery
      final updatedParams = jsonEncode({
        'mode': state.mode.name,
        'width': state.width,
        'height': state.height,
        'duration': state.duration,
        if (state.inputImagePath != null) 'input_image': state.inputImagePath,
        if (remoteTaskId != null) 'remote_task_id': remoteTaskId,
      });

      await dao.updateTaskFields(
        taskId,
        AiTasksCompanion(inputParams: Value(updatedParams)),
      );

      if (response.status == 'completed' && response.videoUrl != null) {
        // Rare: synchronous completion
        await dao.updateTaskFields(
          taskId,
          AiTasksCompanion(
            status: const Value('completed'),
            outputText: Value(jsonEncode(response.toJson())),
            completedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
        state = state.copyWith(
          isSubmitting: false,
          currentVideoPath: response.videoUrl,
        );
      } else if (remoteTaskId != null) {
        // Async: start polling
        ref
            .read(videoTaskPollerProvider.notifier)
            .startPolling(
              localTaskId: taskId,
              remoteTaskId: remoteTaskId,
              providerId: state.selectedProviderId!,
            );
        state = state.copyWith(isSubmitting: false);
      } else {
        throw Exception('API 未返回 taskId，无法轮询任务状态');
      }

      _log.i('Video generation submitted: $taskId');
    } catch (e) {
      await dao.updateTaskFields(
        taskId,
        AiTasksCompanion(
          status: const Value('failed'),
          errorMessage: Value(e.toString()),
          completedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );

      state = state.copyWith(
        isSubmitting: false,
        errorMessage: formatUserError(e),
      );

      _log.e('Video generation failed: $e');
    }
  }

  // -- Save to asset --------------------------------------------------------

  Future<Asset?> saveToAsset({
    required String taskId,
    required String projectId,
    required String name,
  }) async {
    final dao = ref.read(aiTaskDaoProvider);
    final task = await dao.getTaskById(taskId);
    if (task == null || task.outputText == null) return null;

    try {
      final json = jsonDecode(task.outputText!) as Map<String, dynamic>;
      final videoUrl = json['video_url'] as String?;
      if (videoUrl == null) return null;

      final fileManager = ref.read(assetFileManagerProvider);
      final asset = await fileManager.downloadFromUrl(
        url: videoUrl,
        projectId: projectId,
        name: name,
        assetType: 'video',
      );

      await dao.updateTaskFields(
        taskId,
        AiTasksCompanion(outputAssetId: Value(asset.id)),
      );

      _log.i('Saved video to asset: ${asset.name}');
      return asset;
    } catch (e) {
      _log.e('Failed to save video to asset: $e');
      return null;
    }
  }

  // -- Retry ----------------------------------------------------------------

  Future<void> retryFromTask(AiTask task) async {
    if (task.inputPrompt == null) return;

    Map<String, dynamic> params = {};
    if (task.inputParams != null) {
      try {
        params = jsonDecode(task.inputParams!) as Map<String, dynamic>;
      } catch (e) {
        _log.w('[VideoGen] Failed to parse task inputParams', error: e);
      }
    }

    final mode = params['mode'] == 'image2video'
        ? VideoGenMode.image2video
        : VideoGenMode.text2video;

    final videoServices = _serviceManager.getVideoServices();
    final matchingService = videoServices
        .where((s) => s.providerName == task.provider)
        .firstOrNull;

    final w = params['width'] as int? ?? 1280;
    final h = params['height'] as int? ?? 720;
    final resIdx = videoResolutions.indexWhere(
      (r) => r.width == w && r.height == h,
    );

    state = state.copyWith(
      mode: mode,
      prompt: task.inputPrompt!,
      selectedProviderId: matchingService?.providerId,
      selectedModel: task.model,
      width: w,
      height: h,
      duration: params['duration'] as int? ?? 5,
      selectedResolutionIndex: resIdx >= 0 ? resIdx : 0,
      inputImagePath: params['input_image'] as String?,
      clearInputImage: !params.containsKey('input_image'),
      clearError: true,
    );

    await submitGeneration();
  }
}

// ---------------------------------------------------------------------------
// Auxiliary providers
// ---------------------------------------------------------------------------

final videoGenHistoryProvider = StreamProvider.autoDispose<List<AiTask>>((ref) {
  final dao = ref.watch(aiTaskDaoProvider);
  return dao.watchByType('video', limit: 50);
});

final videoGenTaskDetailProvider = FutureProvider.autoDispose
    .family<AiTask?, String>((ref, id) {
      final dao = ref.watch(aiTaskDaoProvider);
      return dao.getTaskById(id);
    });
