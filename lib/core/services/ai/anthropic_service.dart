import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import 'ai_dio_config.dart';
import 'ai_exceptions.dart';
import 'ai_models.dart';
import 'ai_service.dart';

class AnthropicService extends AiService {
  final Dio _dio;
  final List<AiModelInfo>? _modelInfoOverrides;

  @override
  final String providerId;

  static final _log = Logger(printer: PrettyPrinter(methodCount: 0));

  static const _defaultModels = [
    'claude-3-opus-20240229',
    'claude-3-sonnet-20240229',
    'claude-3-haiku-20240307',
    'claude-3-5-sonnet-20241022',
  ];

  static const _anthropicVersion = '2023-06-01';

  AnthropicService({
    required this.providerId,
    required String apiKey,
    String baseUrl = 'https://api.anthropic.com',
    List<AiModelInfo>? modelInfos,
  })  : _modelInfoOverrides = modelInfos,
        _dio = createAiDio(
          baseUrl: baseUrl,
          extraHeaders: {
            'x-api-key': apiKey,
            'anthropic-version': _anthropicVersion,
          },
        );

  @override
  String get providerName => 'Anthropic';

  @override
  List<AiModelInfo> get modelInfos => _modelInfoOverrides ?? [];

  @override
  List<String> get supportedModels => _modelInfoOverrides != null
      ? _modelInfoOverrides.where((m) => m.isEnabled).map((m) => m.id).toList()
      : List.unmodifiable(_defaultModels);

  @override
  bool get supportsChatCompletion => true;

  @override
  bool get supportsImageGeneration => false;

  @override
  bool get supportsVideoGeneration => false;

  // ---------------------------------------------------------------------------
  // Chat
  // ---------------------------------------------------------------------------

  @override
  Future<AiChatResponse> chatCompletion(AiChatRequest request) async {
    try {
      final body = _buildBody(request, stream: false);
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/messages',
        data: body,
      );
      return _parseResponse(response.data!);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  @override
  Stream<String> chatCompletionStream(AiChatRequest request) async* {
    try {
      final body = _buildBody(request, stream: true);
      final response = await _dio.post<ResponseBody>(
        '/v1/messages',
        data: body,
        options: Options(responseType: ResponseType.stream),
      );

      yield* _parseSseStream(response.data!.stream);
    } on DioException catch (e) {
      throw _unwrap(e);
    }
  }

  Map<String, dynamic> _buildBody(AiChatRequest request, {required bool stream}) {
    String? systemPrompt;
    final messages = <Map<String, dynamic>>[];

    for (final m in request.messages) {
      if (m.role == 'system') {
        systemPrompt = m.content;
        continue;
      }

      if (m.imageUrls != null && m.imageUrls!.isNotEmpty) {
        messages.add({
          'role': m.role,
          'content': [
            for (final url in m.imageUrls!)
              if (url.startsWith('data:'))
                _parseDataUrlToAnthropicSource(url)
              else
                {'type': 'image', 'source': {'type': 'url', 'url': url}},
            {'type': 'text', 'text': m.content},
          ],
        });
      } else {
        messages.add({'role': m.role, 'content': m.content});
      }
    }

    return {
      'model': request.model,
      'messages': messages,
      if (systemPrompt != null) 'system': systemPrompt,
      'max_tokens': request.maxTokens ?? 4096,
      'temperature': request.temperature,
      if (stream) 'stream': true,
    };
  }

  Map<String, dynamic> _parseDataUrlToAnthropicSource(String dataUrl) {
    // data:image/jpeg;base64,/9j/4AAQ...
    final commaIdx = dataUrl.indexOf(',');
    final meta = dataUrl.substring(5, commaIdx); // "image/jpeg;base64"
    final mediaType = meta.split(';').first;
    final b64Data = dataUrl.substring(commaIdx + 1);
    return {
      'type': 'image',
      'source': {'type': 'base64', 'media_type': mediaType, 'data': b64Data},
    };
  }

  AiChatResponse _parseResponse(Map<String, dynamic> data) {
    final content = (data['content'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .where((b) => b['type'] == 'text')
            .map((b) => b['text'] as String)
            .join() ??
        '';
    final usage = data['usage'] as Map<String, dynamic>? ?? {};

    return AiChatResponse(
      content: content,
      model: data['model'] as String? ?? '',
      promptTokens: usage['input_tokens'] as int? ?? 0,
      completionTokens: usage['output_tokens'] as int? ?? 0,
      totalTokens: (usage['input_tokens'] as int? ?? 0) +
          (usage['output_tokens'] as int? ?? 0),
    );
  }

  /// Anthropic SSE event types:
  /// - message_start, content_block_start, content_block_delta,
  ///   content_block_stop, message_delta, message_stop
  Stream<String> _parseSseStream(Stream<List<int>> byteStream) async* {
    String buffer = '';
    String? currentEvent;

    await for (final chunk in byteStream) {
      buffer += utf8.decode(chunk);
      final lines = buffer.split('\n');
      buffer = lines.removeLast();

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) {
          currentEvent = null;
          continue;
        }

        if (trimmed.startsWith('event: ')) {
          currentEvent = trimmed.substring(7);
          continue;
        }

        if (!trimmed.startsWith('data: ')) continue;
        final payload = trimmed.substring(6);

        if (currentEvent == 'content_block_delta') {
          try {
            final json = jsonDecode(payload) as Map<String, dynamic>;
            final delta = json['delta'] as Map<String, dynamic>? ?? {};
            if (delta['type'] == 'text_delta') {
              final text = delta['text'] as String?;
              if (text != null && text.isNotEmpty) yield text;
            }
          } on FormatException {
            _log.w('[Anthropic] Failed to parse SSE chunk: $payload');
          }
        } else if (currentEvent == 'message_stop') {
          return;
        } else if (currentEvent == 'error') {
          try {
            final json = jsonDecode(payload) as Map<String, dynamic>;
            final error = json['error'] as Map<String, dynamic>? ?? {};
            throw AiServiceException(
              message: error['message'] as String? ?? 'Stream error',
              userMessage: 'Anthropic 流式响应出错',
            );
          } on FormatException {
            throw AiServiceException(
              message: payload,
              userMessage: 'Anthropic 流式响应出错',
            );
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Connection test
  // ---------------------------------------------------------------------------

  /// Anthropic has no `/models` endpoint, so this sends a minimal chat request
  /// (`maxTokens: 1`) to verify connectivity. This will consume a tiny amount
  /// of API credit.
  @override
  Future<bool> testConnection() async {
    try {
      await chatCompletion(AiChatRequest(
        messages: [
          AiChatMessage(
            role: 'user',
            content: 'Hi',
            timestamp: DateTime.now(),
          ),
        ],
        model: _defaultModels.last,
        maxTokens: 1,
        stream: false,
      ));
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

  static Object _unwrap(DioException e) =>
      e.error is AiServiceException ? e.error! : e;
}
