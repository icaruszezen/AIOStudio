import 'package:dio/dio.dart';

import 'ai_dio_config.dart';
import 'ai_exceptions.dart';
import 'ai_models.dart';
import 'ai_service.dart';
import 'openai_compatible_mixin.dart';

/// OpenAI-compatible custom endpoint service.
///
/// Works with ollama, vllm, one-api, and any other provider that exposes an
/// OpenAI-format REST API.
class CustomService extends AiService with OpenAiCompatibleMixin {
  final Dio _dio;
  final List<AiModelInfo> _modelInfos;

  @override
  final String providerId;

  @override
  final String providerName;

  CustomService({
    required this.providerId,
    required this.providerName,
    required String baseUrl,
    String? apiKey,
    required List<AiModelInfo> modelInfos,
  })  : _modelInfos = List.unmodifiable(modelInfos),
        _dio = createAiDio(
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

  /// Legacy constructor for backward compatibility with plain string lists.
  factory CustomService.fromStringModels({
    required String providerId,
    required String providerName,
    required String baseUrl,
    String? apiKey,
    required List<String> models,
    bool chatEnabled = true,
    bool imageEnabled = false,
  }) {
    final infos = models
        .map((m) => AiModelInfo(
              id: m,
              mode: imageEnabled ? 'image_generation' : 'chat',
            ))
        .toList();
    return CustomService(
      providerId: providerId,
      providerName: providerName,
      baseUrl: baseUrl,
      apiKey: apiKey,
      modelInfos: infos,
    );
  }

  @override
  List<AiModelInfo> get modelInfos => _modelInfos;

  @override
  List<String> get supportedModels =>
      _modelInfos.where((m) => m.isEnabled).map((m) => m.id).toList();

  @override
  List<String> get imageModels => _modelInfos
      .where((m) => m.isEnabled && m.isImageModel)
      .map((m) => m.id)
      .toList();

  @override
  Set<String> get imageGenCapabilities => const {
        ImageGenCap.style,
        ImageGenCap.quality,
      };

  @override
  bool get supportsChatCompletion =>
      _modelInfos.any((m) => m.isEnabled && m.isChatModel);

  @override
  bool get supportsImageGeneration =>
      _modelInfos.any((m) => m.isEnabled && m.isImageModel);

  @override
  bool get supportsVideoGeneration => false;

  // ---------------------------------------------------------------------------
  // Chat (OpenAI-compatible format)
  // ---------------------------------------------------------------------------

  @override
  Future<AiChatResponse> chatCompletion(AiChatRequest request) async {
    try {
      final body = buildOpenAiChatBody(request, stream: false);
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/chat/completions',
        data: body,
      );
      return parseOpenAiChatResponse(response.data!);
    } on DioException catch (e) {
      throw OpenAiCompatibleMixin.unwrapDioError(e);
    }
  }

  @override
  Stream<String> chatCompletionStream(
    AiChatRequest request, {
    CancelToken? cancelToken,
  }) async* {
    try {
      final body = buildOpenAiChatBody(request, stream: true);
      final response = await _dio.post<ResponseBody>(
        '/v1/chat/completions',
        data: body,
        options: Options(responseType: ResponseType.stream),
        cancelToken: cancelToken,
      );

      yield* parseOpenAiSseStream(response.data!.stream);
    } on DioException catch (e) {
      throw OpenAiCompatibleMixin.unwrapDioError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Image (OpenAI-compatible format)
  // ---------------------------------------------------------------------------

  @override
  Future<AiImageResponse> generateImage(AiImageRequest request) async {
    if (!supportsImageGeneration) {
      throw UnsupportedError('$providerName 不支持图片生成');
    }

    try {
      final body = <String, dynamic>{
        'model': request.model,
        'prompt': request.prompt,
        'n': request.count,
        'size': '${request.width}x${request.height}',
      };
      if (request.quality != null) body['quality'] = request.quality;
      if (request.style != null) body['style'] = request.style;

      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/images/generations',
        data: body,
      );
      return AiImageResponse.fromJson(response.data!);
    } on DioException catch (e) {
      throw OpenAiCompatibleMixin.unwrapDioError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Connection test
  // ---------------------------------------------------------------------------

  @override
  Future<bool> testConnection() async {
    try {
      await _dio.get('/v1/models');
      return true;
    } on DioException catch (e) {
      throw OpenAiCompatibleMixin.unwrapDioError(e);
    } catch (e) {
      throw AiServiceException(
        message: e.toString(),
        userMessage: '连接测试失败',
      );
    }
  }

  @override
  void dispose() => _dio.close();
}
