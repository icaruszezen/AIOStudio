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
  final List<String> _models;
  final bool _chatEnabled;
  final bool _imageEnabled;

  @override
  final String providerId;

  @override
  final String providerName;

  CustomService({
    required this.providerId,
    required this.providerName,
    required String baseUrl,
    String? apiKey,
    required List<String> models,
    bool chatEnabled = true,
    bool imageEnabled = false,
  })  : _models = List.unmodifiable(models),
        _chatEnabled = chatEnabled,
        _imageEnabled = imageEnabled,
        _dio = createAiDio(
          baseUrl: baseUrl,
          apiKey: apiKey,
        );

  @override
  List<String> get supportedModels => _models;

  @override
  List<String> get imageModels => _imageEnabled ? _models : [];

  @override
  bool get supportsChatCompletion => _chatEnabled;

  @override
  bool get supportsImageGeneration => _imageEnabled;

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
  Stream<String> chatCompletionStream(AiChatRequest request) async* {
    try {
      final body = buildOpenAiChatBody(request, stream: true);
      final response = await _dio.post<ResponseBody>(
        '/v1/chat/completions',
        data: body,
        options: Options(responseType: ResponseType.stream),
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
    if (!_imageEnabled) {
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
    } on AiServiceException {
      rethrow;
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
