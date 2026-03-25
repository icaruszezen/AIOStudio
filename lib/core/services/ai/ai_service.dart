import 'package:dio/dio.dart';

import 'ai_exceptions.dart';
import 'ai_models.dart';

/// Well-known capability keys for [AiService.imageGenCapabilities].
abstract class ImageGenCap {
  static const style = 'style';
  static const quality = 'quality';
  static const cfgScale = 'cfg_scale';
  static const steps = 'steps';
  static const seed = 'seed';
  static const negativePrompt = 'negative_prompt';
}

/// Base contract for all AI service provider implementations.
///
/// Concrete implementations should override capability flags
/// ([supportsChatCompletion], [supportsImageGeneration],
/// [supportsVideoGeneration]) and only implement the corresponding methods.
/// Calling an unsupported method throws [UnsupportedError].
abstract class AiService {
  /// Human-readable provider name (e.g. "OpenAI", "Anthropic").
  String get providerName;

  /// Unique config id from the database.
  String get providerId;

  /// Model identifiers this provider supports.
  List<String> get supportedModels;

  /// Model identifiers for image generation only.
  List<String> get imageModels => [];

  /// Model identifiers for video generation only.
  List<String> get videoModels => [];

  /// Rich model metadata. Implementations that support user-customised model
  /// lists should override this to return the full [AiModelInfo] objects.
  List<AiModelInfo> get modelInfos => [];

  /// Provider type tag for UI branching (e.g. 'openai', 'stability', 'custom').
  String get providerType => 'custom';

  /// Capability tags for image generation parameters. UI uses these to
  /// decide which parameter controls to show instead of hard-coding
  /// provider/model names. See [ImageGenCap] for well-known keys.
  Set<String> get imageGenCapabilities => const {};

  bool get supportsChatCompletion;
  bool get supportsImageGeneration;
  bool get supportsVideoGeneration;

  Future<AiChatResponse> chatCompletion(AiChatRequest request) async =>
      throw UnsupportedError('$providerName 不支持对话补全');

  Stream<String> chatCompletionStream(
    AiChatRequest request, {
    CancelToken? cancelToken,
  }) async* {
    throw UnsupportedError('$providerName 不支持流式对话');
  }

  Future<AiImageResponse> generateImage(AiImageRequest request) async =>
      throw UnsupportedError('$providerName 不支持图片生成');

  Future<AiVideoResponse> generateVideo(AiVideoRequest request) async =>
      throw UnsupportedError('$providerName 不支持视频生成');

  Future<AiVideoResponse> checkVideoStatus(String taskId) async =>
      throw UnsupportedError('$providerName 不支持视频任务查询');

  /// Quick connectivity check – returns `true` on success, throws
  /// [AiServiceException] on failure.
  Future<bool> testConnection();

  /// Releases resources held by this service (e.g. HTTP clients).
  void dispose() {}
}
