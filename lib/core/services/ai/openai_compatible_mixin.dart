import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import 'ai_exceptions.dart';
import 'ai_models.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

/// Shared request-building, response-parsing, and SSE-streaming logic for
/// services that expose an OpenAI-compatible REST API (OpenAI itself, ollama,
/// vllm, one-api, etc.).
mixin OpenAiCompatibleMixin {
  String get providerName;

  Map<String, dynamic> buildOpenAiChatBody(
    AiChatRequest request, {
    required bool stream,
  }) {
    final messages = request.messages.map((m) {
      if (m.imageUrls != null && m.imageUrls!.isNotEmpty) {
        return {
          'role': m.role,
          'content': [
            {'type': 'text', 'text': m.content},
            for (final url in m.imageUrls!)
              {'type': 'image_url', 'image_url': {'url': url}},
          ],
        };
      }
      return {'role': m.role, 'content': m.content};
    }).toList();

    return {
      'model': request.model,
      'messages': messages,
      'temperature': request.temperature,
      if (request.maxTokens != null) 'max_tokens': request.maxTokens,
      'stream': stream,
    };
  }

  AiChatResponse parseOpenAiChatResponse(Map<String, dynamic> data) {
    final choices = data['choices'] as List<dynamic>? ?? [];
    final content = choices.isNotEmpty
        ? (choices[0] as Map<String, dynamic>)['message']['content']
                as String? ??
            ''
        : '';
    final usage = data['usage'] as Map<String, dynamic>? ?? {};

    return AiChatResponse(
      content: content,
      model: data['model'] as String? ?? '',
      promptTokens: usage['prompt_tokens'] as int? ?? 0,
      completionTokens: usage['completion_tokens'] as int? ?? 0,
      totalTokens: usage['total_tokens'] as int? ?? 0,
    );
  }

  Stream<String> parseOpenAiSseStream(Stream<List<int>> byteStream) async* {
    String buffer = '';
    await for (final text in utf8.decoder.bind(byteStream)) {
      buffer += text;
      final lines = buffer.split('\n');
      buffer = lines.removeLast();

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith(':')) continue;
        if (!trimmed.startsWith('data: ')) continue;

        final payload = trimmed.substring(6);
        if (payload == '[DONE]') return;

        try {
          final json = jsonDecode(payload) as Map<String, dynamic>;
          final choices = json['choices'] as List<dynamic>? ?? [];
          if (choices.isEmpty) continue;
          final delta = (choices[0] as Map<String, dynamic>)['delta']
              as Map<String, dynamic>? ??
              {};
          final content = delta['content'] as String?;
          if (content != null && content.isNotEmpty) yield content;
        } on FormatException {
          _log.w('[$providerName] Failed to parse SSE chunk: $payload');
        }
      }
    }
  }

  static AiServiceException unwrapDioError(DioException e) =>
      e.error is AiServiceException
          ? e.error! as AiServiceException
          : AiServiceException(
              message: e.message ?? e.toString(),
              userMessage: '网络请求异常',
              statusCode: e.response?.statusCode,
              originalError: e,
            );
}
