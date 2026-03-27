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

// ---------------------------------------------------------------------------
// Size presets
// ---------------------------------------------------------------------------

class SizePreset {
  final String label;
  final int width;
  final int height;

  const SizePreset(this.label, this.width, this.height);
}

const sizePresets = [
  SizePreset('1024 × 1024', 1024, 1024),
  SizePreset('1024 × 1792', 1024, 1792),
  SizePreset('1792 × 1024', 1792, 1024),
  SizePreset('512 × 512', 512, 512),
  SizePreset('自定义', 0, 0),
];

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class ImageGenState {
  final String? selectedProviderId;
  final String? selectedModel;
  final String prompt;
  final String negativePrompt;
  final int width;
  final int height;
  final int count;
  final String? style;
  final String? quality;
  final double? cfgScale;
  final int? steps;
  final int? seed;
  final int selectedSizePreset;
  final bool isGenerating;
  final AiImageResponse? currentResult;
  final String? currentTaskId;
  final String? errorMessage;
  final bool showHistory;

  const ImageGenState({
    this.selectedProviderId,
    this.selectedModel,
    this.prompt = '',
    this.negativePrompt = '',
    this.width = 1024,
    this.height = 1024,
    this.count = 1,
    this.style,
    this.quality,
    this.cfgScale,
    this.steps,
    this.seed,
    this.selectedSizePreset = 0,
    this.isGenerating = false,
    this.currentResult,
    this.currentTaskId,
    this.errorMessage,
    this.showHistory = false,
  });

  ImageGenState copyWith({
    String? selectedProviderId,
    String? selectedModel,
    String? prompt,
    String? negativePrompt,
    int? width,
    int? height,
    int? count,
    String? style,
    String? quality,
    double? cfgScale,
    int? steps,
    int? seed,
    int? selectedSizePreset,
    bool? isGenerating,
    AiImageResponse? currentResult,
    String? currentTaskId,
    String? errorMessage,
    bool? showHistory,
    bool clearProvider = false,
    bool clearModel = false,
    bool clearResult = false,
    bool clearError = false,
    bool clearStyle = false,
    bool clearQuality = false,
    bool clearCfgScale = false,
    bool clearSteps = false,
    bool clearSeed = false,
    bool clearTaskId = false,
  }) {
    return ImageGenState(
      selectedProviderId: clearProvider
          ? null
          : (selectedProviderId ?? this.selectedProviderId),
      selectedModel: clearModel ? null : (selectedModel ?? this.selectedModel),
      prompt: prompt ?? this.prompt,
      negativePrompt: negativePrompt ?? this.negativePrompt,
      width: width ?? this.width,
      height: height ?? this.height,
      count: count ?? this.count,
      style: clearStyle ? null : (style ?? this.style),
      quality: clearQuality ? null : (quality ?? this.quality),
      cfgScale: clearCfgScale ? null : (cfgScale ?? this.cfgScale),
      steps: clearSteps ? null : (steps ?? this.steps),
      seed: clearSeed ? null : (seed ?? this.seed),
      selectedSizePreset: selectedSizePreset ?? this.selectedSizePreset,
      isGenerating: isGenerating ?? this.isGenerating,
      currentResult: clearResult ? null : (currentResult ?? this.currentResult),
      currentTaskId: clearTaskId ? null : (currentTaskId ?? this.currentTaskId),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      showHistory: showHistory ?? this.showHistory,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

final imageGenProvider = NotifierProvider<ImageGenNotifier, ImageGenState>(
  ImageGenNotifier.new,
);

class ImageGenNotifier extends Notifier<ImageGenState> {
  static final _log = Logger(printer: PrettyPrinter(methodCount: 0));
  static const _uuid = Uuid();

  final _cancelledTaskIds = <String>{};

  AiServiceManager get _serviceManager => ref.read(aiServiceManagerProvider);

  @override
  ImageGenState build() {
    _initDefaultProvider();
    return const ImageGenState();
  }

  Future<void> _initDefaultProvider() async {
    final manager = await ref.read(aiServicesReadyProvider.future);
    if (state.selectedProviderId != null) return;
    final imageServices = manager.getImageServices();
    if (imageServices.isNotEmpty) {
      final service = imageServices.first;
      final models = service.imageModels;
      state = state.copyWith(
        selectedProviderId: service.providerId,
        selectedModel: models.isNotEmpty ? models.first : null,
      );
    }
  }

  // -- Provider / Model selection -------------------------------------------

  void selectProvider(String providerId) {
    final service = _serviceManager.getService(providerId);
    if (service == null) return;
    final models = service.imageModels;
    state = state.copyWith(
      selectedProviderId: providerId,
      selectedModel: models.isNotEmpty ? models.first : null,
      clearStyle: true,
      clearQuality: true,
      clearCfgScale: true,
      clearSteps: true,
    );
  }

  void selectModel(String model) {
    state = state.copyWith(selectedModel: model);
  }

  List<AiService> getAvailableProviders() {
    return _serviceManager.getImageServices();
  }

  List<String> getProviderImageModels(String providerId) {
    final service = _serviceManager.getService(providerId);
    return service?.imageModels ?? [];
  }

  Set<String> getImageGenCapabilities() {
    if (state.selectedProviderId == null) return const {};
    final service = _serviceManager.getService(state.selectedProviderId!);
    return service?.imageGenCapabilities ?? const {};
  }

  // -- Prompt ---------------------------------------------------------------

  void updatePrompt(String text) =>
      state = state.copyWith(prompt: text, clearError: true);

  void updateNegativePrompt(String text) =>
      state = state.copyWith(negativePrompt: text);

  // -- Size -----------------------------------------------------------------

  void selectSizePreset(int index) {
    if (index < 0 || index >= sizePresets.length) return;
    final preset = sizePresets[index];
    if (preset.width == 0) {
      state = state.copyWith(selectedSizePreset: index);
    } else {
      state = state.copyWith(
        selectedSizePreset: index,
        width: preset.width,
        height: preset.height,
      );
    }
  }

  void setCustomSize(int w, int h) =>
      state = state.copyWith(width: w, height: h);

  // -- Generation params ----------------------------------------------------

  void setCount(int n) => state = state.copyWith(count: n.clamp(1, 4));
  void setStyle(String? s) => s == null
      ? state = state.copyWith(clearStyle: true)
      : state = state.copyWith(style: s);
  void setQuality(String? q) => q == null
      ? state = state.copyWith(clearQuality: true)
      : state = state.copyWith(quality: q);
  void setCfgScale(double? v) => v == null
      ? state = state.copyWith(clearCfgScale: true)
      : state = state.copyWith(cfgScale: v);
  void setSteps(int? v) => v == null
      ? state = state.copyWith(clearSteps: true)
      : state = state.copyWith(steps: v);
  void setSeed(int? v) => v == null
      ? state = state.copyWith(clearSeed: true)
      : state = state.copyWith(seed: v);

  void toggleHistory() =>
      state = state.copyWith(showHistory: !state.showHistory);

  // -- Cancel ---------------------------------------------------------------

  void cancelGeneration() {
    if (!state.isGenerating || state.currentTaskId == null) return;
    _cancelledTaskIds.add(state.currentTaskId!);
    state = state.copyWith(
      isGenerating: false,
      clearError: true,
      clearTaskId: true,
    );
  }

  // -- Generation -----------------------------------------------------------

  Future<void> generateImage() async {
    if (state.isGenerating) return;
    if (state.prompt.trim().isEmpty) return;
    if (state.selectedProviderId == null || state.selectedModel == null) return;

    final service = _serviceManager.getService(state.selectedProviderId!);
    if (service == null) return;

    final dao = ref.read(aiTaskDaoProvider);
    final taskId = _uuid.v4();
    final now = DateTime.now();

    state = state.copyWith(
      isGenerating: true,
      clearResult: true,
      clearError: true,
      currentTaskId: taskId,
    );

    final inputParams = jsonEncode({
      'width': state.width,
      'height': state.height,
      'count': state.count,
      if (state.style != null) 'style': state.style,
      if (state.quality != null) 'quality': state.quality,
      if (state.cfgScale != null) 'cfg_scale': state.cfgScale,
      if (state.steps != null) 'steps': state.steps,
      if (state.seed != null) 'seed': state.seed,
      if (state.negativePrompt.isNotEmpty)
        'negative_prompt': state.negativePrompt,
    });

    await dao.insertTask(
      AiTasksCompanion.insert(
        id: taskId,
        type: 'image',
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
      final request = AiImageRequest(
        prompt: state.prompt,
        negativePrompt: state.negativePrompt.isEmpty
            ? null
            : state.negativePrompt,
        model: state.selectedModel!,
        width: state.width,
        height: state.height,
        count: state.count,
        style: state.style,
        quality: state.quality,
        cfgScale: state.cfgScale,
        steps: state.steps,
        seed: state.seed,
      );

      final response = await service.generateImage(request);

      if (_cancelledTaskIds.remove(taskId)) {
        await dao.updateTaskFields(
          taskId,
          AiTasksCompanion(
            status: const Value('cancelled'),
            completedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
        return;
      }

      final completedAt = DateTime.now().millisecondsSinceEpoch;
      await dao.updateTaskFields(
        taskId,
        AiTasksCompanion(
          status: const Value('completed'),
          outputText: Value(jsonEncode(response.toJson())),
          completedAt: Value(completedAt),
        ),
      );

      state = state.copyWith(
        isGenerating: false,
        currentResult: response,
        showHistory: false,
      );

      _log.i('Image generation completed: ${response.images.length} images');
    } catch (e) {
      if (_cancelledTaskIds.remove(taskId)) {
        await dao.updateTaskFields(
          taskId,
          AiTasksCompanion(
            status: const Value('cancelled'),
            completedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
        return;
      }

      final userMsg = formatUserError(e);
      await dao.updateTaskFields(
        taskId,
        AiTasksCompanion(
          status: const Value('failed'),
          errorMessage: Value(e.toString()),
          completedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );

      state = state.copyWith(isGenerating: false, errorMessage: userMsg);

      _log.e('Image generation failed: $e');
    }
  }

  // -- Save to asset --------------------------------------------------------

  Future<Asset?> saveToAsset({
    required int imageIndex,
    required String projectId,
    required String name,
    List<String> tagIds = const [],
  }) async {
    final result = state.currentResult;
    if (result == null || imageIndex >= result.images.length) return null;

    final image = result.images[imageIndex];
    final fileManager = ref.read(assetFileManagerProvider);

    try {
      Asset asset;
      if (image.base64 != null) {
        asset = await fileManager.saveFromBase64(
          base64Data: image.base64!,
          projectId: projectId,
          name: name,
        );
      } else if (image.url != null) {
        asset = await fileManager.downloadFromUrl(
          url: image.url!,
          projectId: projectId,
          name: name,
          assetType: 'image',
        );
      } else {
        return null;
      }

      if (tagIds.isNotEmpty) {
        final tagDao = ref.read(tagDaoProvider);
        await tagDao.batchAddTagsToAsset(asset.id, tagIds);
      }

      if (state.currentTaskId != null) {
        final dao = ref.read(aiTaskDaoProvider);
        final task = await dao.getTaskById(state.currentTaskId!);
        final savedIds = _extractSavedAssetIds(task?.outputText)..add(asset.id);

        final outputJson = task?.outputText != null
            ? (jsonDecode(task!.outputText!) as Map<String, dynamic>)
            : <String, dynamic>{};
        outputJson['_savedAssetIds'] = savedIds;

        await dao.updateTaskFields(
          state.currentTaskId!,
          AiTasksCompanion(
            outputAssetId: Value(asset.id),
            outputText: Value(jsonEncode(outputJson)),
          ),
        );
      }

      _log.i('Saved image to asset: ${asset.name}');
      return asset;
    } catch (e) {
      _log.e('Failed to save image to asset: $e');
      return null;
    }
  }

  static List<String> _extractSavedAssetIds(String? outputText) {
    if (outputText == null) return [];
    try {
      final json = jsonDecode(outputText) as Map<String, dynamic>;
      return ((json['_savedAssetIds'] as List<dynamic>?) ?? []).cast<String>();
    } catch (e) {
      _log.w('[ImageGen] Failed to parse saved asset IDs', error: e);
      return [];
    }
  }

  // -- Delete task ----------------------------------------------------------

  Future<void> deleteTask(String taskId) async {
    final dao = ref.read(aiTaskDaoProvider);
    await dao.deleteTask(taskId);
  }

  // -- Retry ----------------------------------------------------------------

  Future<void> retryFromTask(AiTask task) async {
    if (task.inputPrompt == null) return;

    Map<String, dynamic> params = {};
    if (task.inputParams != null) {
      try {
        params = jsonDecode(task.inputParams!) as Map<String, dynamic>;
      } catch (e) {
        _log.w('[ImageGen] Failed to parse task inputParams', error: e);
      }
    }

    final providers = getAvailableProviders();
    final matchedService = providers
        .where((s) => s.providerName == task.provider)
        .firstOrNull;

    state = state.copyWith(
      selectedProviderId:
          matchedService?.providerId ?? state.selectedProviderId,
      selectedModel: task.model ?? state.selectedModel,
      prompt: task.inputPrompt!,
      negativePrompt: params['negative_prompt'] as String? ?? '',
      width: params['width'] as int? ?? 1024,
      height: params['height'] as int? ?? 1024,
      count: params['count'] as int? ?? 1,
      style: params['style'] as String?,
      quality: params['quality'] as String?,
      cfgScale: (params['cfg_scale'] as num?)?.toDouble(),
      steps: params['steps'] as int?,
      seed: params['seed'] as int?,
      clearStyle: !params.containsKey('style'),
      clearQuality: !params.containsKey('quality'),
      clearCfgScale: !params.containsKey('cfg_scale'),
      clearSteps: !params.containsKey('steps'),
      clearSeed: !params.containsKey('seed'),
      showHistory: false,
    );

    await generateImage();
  }
}

// ---------------------------------------------------------------------------
// Auxiliary providers
// ---------------------------------------------------------------------------

const _historyPageSize = 50;

final imageGenHistoryProvider = StreamProvider.autoDispose<List<AiTask>>((ref) {
  final dao = ref.watch(aiTaskDaoProvider);
  return dao.watchByType('image', limit: _historyPageSize);
});

final imageGenTaskDetailProvider = FutureProvider.autoDispose
    .family<AiTask?, String>((ref, id) {
      final dao = ref.watch(aiTaskDaoProvider);
      return dao.getTaskById(id);
    });
