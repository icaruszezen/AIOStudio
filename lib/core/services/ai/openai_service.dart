import 'package:dio/dio.dart';

import 'ai_dio_config.dart';
import 'ai_exceptions.dart';
import 'ai_models.dart';
import 'ai_service.dart';
import 'openai_compatible_mixin.dart';

class OpenAiService extends AiService with OpenAiCompatibleMixin {
  final Dio _dio;
  final List<AiModelInfo>? _modelInfoOverrides;

  @override
  final String providerId;

  static const _defaultChatModels = [
    'gpt-4o',
    'gpt-4o-mini',
    'gpt-4-turbo',
    'gpt-3.5-turbo',
  ];

  static const _defaultImageModels = ['dall-e-3', 'dall-e-2'];

  static const _defaultAllModels = [..._defaultChatModels, ..._defaultImageModels];

  OpenAiService({
    required this.providerId,
    required String apiKey,
    String baseUrl = 'https://api.openai.com',
    List<AiModelInfo>? modelInfos,
  })  : _modelInfoOverrides = modelInfos,
        _dio = createAiDio(baseUrl: baseUrl, apiKey: apiKey);

  @override
  String get providerName => 'OpenAI';

  @override
  List<AiModelInfo> get modelInfos => _modelInfoOverrides ?? [];

  @override
  List<String> get supportedModels => _modelInfoOverrides != null
      ? _modelInfoOverrides.where((m) => m.isEnabled).map((m) => m.id).toList()
      : _defaultAllModels;

  @override
  List<String> get imageModels => _modelInfoOverrides != null
      ? _modelInfoOverrides
          .where((m) => m.isEnabled && m.isImageModel)
          .map((m) => m.id)
          .toList()
      : _defaultImageModels;

  @override
  String get providerType => 'openai';

  @override
  Set<String> get imageGenCapabilities => const {
        ImageGenCap.style,
        ImageGenCap.quality,
      };

  @override
  bool get supportsChatCompletion => true;

  @override
  bool get supportsImageGeneration => true;

  @override
  bool get supportsVideoGeneration => false;

  // ---------------------------------------------------------------------------
  // Chat
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
  // Image
  // ---------------------------------------------------------------------------

  @override
  Future<AiImageResponse> generateImage(AiImageRequest request) async {
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
