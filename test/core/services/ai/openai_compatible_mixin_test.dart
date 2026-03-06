import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:aio_studio/core/services/ai/ai_models.dart';
import 'package:aio_studio/core/services/ai/openai_compatible_mixin.dart';

class _TestService with OpenAiCompatibleMixin {
  @override
  String get providerName => 'Test';
}

Stream<List<int>> _sseStream(List<String> lines) {
  return Stream.fromIterable(lines.map((l) => utf8.encode('$l\n')));
}

void main() {
  late _TestService service;

  setUp(() {
    service = _TestService();
  });

  final now = DateTime(2025, 1, 1);

  group('buildOpenAiChatBody', () {
    test('basic request without images', () {
      final request = AiChatRequest(
        model: 'gpt-4',
        messages: [
          AiChatMessage(role: 'user', content: 'Hello', timestamp: now),
        ],
      );

      final body = service.buildOpenAiChatBody(request, stream: false);

      expect(body['model'], 'gpt-4');
      expect(body['temperature'], 0.7);
      expect(body['stream'], false);
      expect(body.containsKey('max_tokens'), false);

      final messages = body['messages'] as List;
      expect(messages.length, 1);
      expect(messages[0], {'role': 'user', 'content': 'Hello'});
    });

    test('request with images produces content array', () {
      final request = AiChatRequest(
        model: 'gpt-4o',
        messages: [
          AiChatMessage(
            role: 'user',
            content: 'Describe this',
            imageUrls: ['https://img.example.com/a.png'],
            timestamp: now,
          ),
        ],
      );

      final body = service.buildOpenAiChatBody(request, stream: true);
      final messages = body['messages'] as List;
      final content = messages[0]['content'] as List;

      expect(content[0], {'type': 'text', 'text': 'Describe this'});
      expect(content[1], {
        'type': 'image_url',
        'image_url': {'url': 'https://img.example.com/a.png'},
      });
    });

    test('request with multiple images', () {
      final request = AiChatRequest(
        model: 'gpt-4o',
        messages: [
          AiChatMessage(
            role: 'user',
            content: 'Compare',
            imageUrls: ['https://a.png', 'https://b.png'],
            timestamp: now,
          ),
        ],
      );

      final body = service.buildOpenAiChatBody(request, stream: false);
      final content = (body['messages'] as List)[0]['content'] as List;

      expect(content.length, 3);
    });

    test('maxTokens included when set', () {
      final request = AiChatRequest(
        model: 'gpt-4',
        messages: [
          AiChatMessage(role: 'user', content: 'Hi', timestamp: now),
        ],
        maxTokens: 256,
      );

      final body = service.buildOpenAiChatBody(request, stream: false);
      expect(body['max_tokens'], 256);
    });

    test('stream flag propagated', () {
      final request = AiChatRequest(
        model: 'gpt-4',
        messages: [
          AiChatMessage(role: 'user', content: 'Hi', timestamp: now),
        ],
      );

      expect(
        service.buildOpenAiChatBody(request, stream: true)['stream'],
        true,
      );
      expect(
        service.buildOpenAiChatBody(request, stream: false)['stream'],
        false,
      );
    });

    test('empty imageUrls list treated as no images', () {
      final request = AiChatRequest(
        model: 'gpt-4',
        messages: [
          AiChatMessage(
            role: 'user',
            content: 'Hi',
            imageUrls: [],
            timestamp: now,
          ),
        ],
      );

      final body = service.buildOpenAiChatBody(request, stream: false);
      final msg = (body['messages'] as List)[0];
      expect(msg['content'], isA<String>());
    });
  });

  group('parseOpenAiChatResponse', () {
    test('parses normal response', () {
      final data = {
        'model': 'gpt-4',
        'choices': [
          {
            'message': {'content': 'Hello there!'}
          }
        ],
        'usage': {
          'prompt_tokens': 10,
          'completion_tokens': 5,
          'total_tokens': 15,
        },
      };

      final resp = service.parseOpenAiChatResponse(data);

      expect(resp.content, 'Hello there!');
      expect(resp.model, 'gpt-4');
      expect(resp.promptTokens, 10);
      expect(resp.completionTokens, 5);
      expect(resp.totalTokens, 15);
    });

    test('empty choices returns empty content', () {
      final data = {
        'model': 'gpt-4',
        'choices': <dynamic>[],
        'usage': {
          'prompt_tokens': 0,
          'completion_tokens': 0,
          'total_tokens': 0,
        },
      };

      final resp = service.parseOpenAiChatResponse(data);
      expect(resp.content, '');
    });

    test('missing choices key returns empty content', () {
      final data = {'model': 'gpt-4'};

      final resp = service.parseOpenAiChatResponse(data);
      expect(resp.content, '');
      expect(resp.promptTokens, 0);
    });

    test('missing usage returns zero tokens', () {
      final data = {
        'model': 'gpt-4',
        'choices': [
          {
            'message': {'content': 'ok'}
          }
        ],
      };

      final resp = service.parseOpenAiChatResponse(data);
      expect(resp.content, 'ok');
      expect(resp.promptTokens, 0);
      expect(resp.completionTokens, 0);
      expect(resp.totalTokens, 0);
    });

    test('null content in message returns empty string', () {
      final data = {
        'model': 'gpt-4',
        'choices': [
          {
            'message': {'content': null}
          }
        ],
      };

      final resp = service.parseOpenAiChatResponse(data);
      expect(resp.content, '');
    });
  });

  group('parseOpenAiSseStream', () {
    test('parses normal SSE chunks', () async {
      final stream = _sseStream([
        'data: ${jsonEncode({
              'choices': [
                {
                  'delta': {'content': 'Hello'}
                }
              ]
            })}',
        'data: ${jsonEncode({
              'choices': [
                {
                  'delta': {'content': ' world'}
                }
              ]
            })}',
        'data: [DONE]',
      ]);

      final tokens = await service.parseOpenAiSseStream(stream).toList();
      expect(tokens, ['Hello', ' world']);
    });

    test('[DONE] terminates the stream', () async {
      final stream = _sseStream([
        'data: ${jsonEncode({
              'choices': [
                {
                  'delta': {'content': 'A'}
                }
              ]
            })}',
        'data: [DONE]',
        'data: ${jsonEncode({
              'choices': [
                {
                  'delta': {'content': 'B'}
                }
              ]
            })}',
      ]);

      final tokens = await service.parseOpenAiSseStream(stream).toList();
      expect(tokens, ['A']);
    });

    test('malformed JSON is skipped', () async {
      final stream = _sseStream([
        'data: {bad json',
        'data: ${jsonEncode({
              'choices': [
                {
                  'delta': {'content': 'ok'}
                }
              ]
            })}',
        'data: [DONE]',
      ]);

      final tokens = await service.parseOpenAiSseStream(stream).toList();
      expect(tokens, ['ok']);
    });

    test('empty content is skipped', () async {
      final stream = _sseStream([
        'data: ${jsonEncode({
              'choices': [
                {
                  'delta': {'content': ''}
                }
              ]
            })}',
        'data: ${jsonEncode({
              'choices': [
                {
                  'delta': {'content': 'yes'}
                }
              ]
            })}',
        'data: [DONE]',
      ]);

      final tokens = await service.parseOpenAiSseStream(stream).toList();
      expect(tokens, ['yes']);
    });

    test('null content in delta is skipped', () async {
      final stream = _sseStream([
        'data: ${jsonEncode({
              'choices': [
                {'delta': <String, dynamic>{}}
              ]
            })}',
        'data: ${jsonEncode({
              'choices': [
                {
                  'delta': {'content': 'hi'}
                }
              ]
            })}',
        'data: [DONE]',
      ]);

      final tokens = await service.parseOpenAiSseStream(stream).toList();
      expect(tokens, ['hi']);
    });

    test('empty choices array is skipped', () async {
      final stream = _sseStream([
        'data: ${jsonEncode({'choices': <dynamic>[]})}',
        'data: ${jsonEncode({
              'choices': [
                {
                  'delta': {'content': 'x'}
                }
              ]
            })}',
        'data: [DONE]',
      ]);

      final tokens = await service.parseOpenAiSseStream(stream).toList();
      expect(tokens, ['x']);
    });

    test('SSE comment lines (starting with :) are ignored', () async {
      final stream = _sseStream([
        ': this is a comment',
        'data: ${jsonEncode({
              'choices': [
                {
                  'delta': {'content': 'val'}
                }
              ]
            })}',
        'data: [DONE]',
      ]);

      final tokens = await service.parseOpenAiSseStream(stream).toList();
      expect(tokens, ['val']);
    });

    test('blank lines are ignored', () async {
      final stream = _sseStream([
        '',
        'data: ${jsonEncode({
              'choices': [
                {
                  'delta': {'content': 'z'}
                }
              ]
            })}',
        '',
        'data: [DONE]',
      ]);

      final tokens = await service.parseOpenAiSseStream(stream).toList();
      expect(tokens, ['z']);
    });
  });
}
