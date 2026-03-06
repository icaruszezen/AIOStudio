import 'package:dio/dio.dart';

import 'ai_dio_config.dart';
import 'ai_exceptions.dart';
import 'ai_models.dart';
import 'ai_service.dart';

class StabilityService extends AiService {
  final Dio _dio;

  @override
  final String providerId;

  static const _models = [
    'sd3-large',
    'sd3-large-turbo',
    'sd3-medium',
    'stable-image-core',
  ];

  StabilityService({
    required this.providerId,
    required String apiKey,
    String baseUrl = 'https://api.stability.ai',
  }) : _dio = createAiDio(
          baseUrl: baseUrl,
          apiKey: apiKey,
          extraHeaders: {'Accept': 'application/json'},
        );

  @override
  String get providerName => 'Stability AI';

  @override
  List<String> get supportedModels => List.unmodifiable(_models);

  @override
  List<String> get imageModels => List.unmodifiable(_models);

  @override
  String get providerType => 'stability';

  @override
  bool get supportsChatCompletion => false;

  @override
  bool get supportsImageGeneration => true;

  @override
  bool get supportsVideoGeneration => false;

  // ---------------------------------------------------------------------------
  // Image generation
  // ---------------------------------------------------------------------------

  @override
  Future<AiImageResponse> generateImage(AiImageRequest request) async {
    try {
      final formData = FormData.fromMap({
        'prompt': request.prompt,
        if (request.negativePrompt != null)
          'negative_prompt': request.negativePrompt,
        'output_format': 'png',
        'aspect_ratio': _aspectRatio(request.width, request.height),
        if (request.cfgScale != null) 'cfg_scale': request.cfgScale,
        if (request.steps != null) 'steps': request.steps,
        if (request.seed != null) 'seed': request.seed,
      });

      final response = await _dio.post<Map<String, dynamic>>(
        '/v2beta/stable-image/generate/sd3',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      final data = response.data!;

      // Single-image response: { "image": "<base64>", "finish_reason": "..." }
      if (data.containsKey('image')) {
        return AiImageResponse(images: [
          AiGeneratedImage(base64: data['image'] as String),
        ]);
      }

      // Array response (future-proofing)
      if (data.containsKey('artifacts')) {
        final artifacts = data['artifacts'] as List<dynamic>;
        return AiImageResponse(
          images: artifacts.map((a) {
            final art = a as Map<String, dynamic>;
            return AiGeneratedImage(
              base64: art['base64'] as String?,
            );
          }).toList(),
        );
      }

      throw const AiServiceException(
        message: 'Unexpected Stability API response format',
        userMessage: 'Stability AI 返回了无法识别的响应格式',
      );
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Connection test
  // ---------------------------------------------------------------------------

  @override
  Future<bool> testConnection() async {
    try {
      await _dio.get('/v1/engines/list');
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

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static String _aspectRatio(int w, int h) {
    // Map common pixel sizes to Stability's aspect_ratio parameter
    final ratio = w / h;
    if ((ratio - 1.0).abs() < 0.05) return '1:1';
    if ((ratio - 16 / 9).abs() < 0.1) return '16:9';
    if ((ratio - 9 / 16).abs() < 0.1) return '9:16';
    if ((ratio - 4 / 3).abs() < 0.1) return '4:3';
    if ((ratio - 3 / 4).abs() < 0.1) return '3:4';
    if ((ratio - 21 / 9).abs() < 0.1) return '21:9';
    if ((ratio - 9 / 21).abs() < 0.1) return '9:21';
    return '1:1';
  }

  @override
  void dispose() => _dio.close();

  static Object _unwrap(DioException e) =>
      e.error is AiServiceException ? e.error! : e;
}
