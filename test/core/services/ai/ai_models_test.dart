import 'dart:convert';
import 'dart:typed_data';

import 'package:aio_studio/core/services/ai/ai_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2025, 1, 1);

  group('AiChatMessage', () {
    test('toJson/fromJson roundtrip without imageUrls', () {
      final msg = AiChatMessage(
        role: 'user',
        content: 'hello',
        timestamp: now,
      );

      final json = msg.toJson();
      final restored = AiChatMessage.fromJson(json);

      expect(restored.role, 'user');
      expect(restored.content, 'hello');
      expect(restored.imageUrls, isNull);
      expect(restored.timestamp, now);
    });

    test('toJson/fromJson roundtrip with imageUrls', () {
      final msg = AiChatMessage(
        role: 'user',
        content: 'look',
        imageUrls: ['https://a.png', 'https://b.png'],
        timestamp: now,
      );

      final json = msg.toJson();
      expect(json['image_urls'], ['https://a.png', 'https://b.png']);

      final restored = AiChatMessage.fromJson(json);
      expect(restored.imageUrls, ['https://a.png', 'https://b.png']);
    });

    test('toJson omits image_urls when null', () {
      final msg = AiChatMessage(
        role: 'assistant',
        content: 'hi',
        timestamp: now,
      );

      expect(msg.toJson().containsKey('image_urls'), false);
    });

    test('fromJson uses DateTime.now() when timestamp missing', () {
      final before = DateTime.now();
      final msg = AiChatMessage.fromJson({
        'role': 'user',
        'content': 'test',
      });
      final after = DateTime.now();

      expect(msg.timestamp.isAfter(before) || msg.timestamp == before, true);
      expect(msg.timestamp.isBefore(after) || msg.timestamp == after, true);
    });
  });

  group('AiChatRequest', () {
    test('toJson with all fields', () {
      final request = AiChatRequest(
        model: 'gpt-4',
        messages: [
          AiChatMessage(role: 'user', content: 'hi', timestamp: now),
        ],
        temperature: 0.5,
        maxTokens: 100,
        stream: false,
      );

      final json = request.toJson();
      expect(json['model'], 'gpt-4');
      expect(json['temperature'], 0.5);
      expect(json['max_tokens'], 100);
      expect(json['stream'], false);
      expect((json['messages'] as List).length, 1);
    });

    test('toJson omits max_tokens when null', () {
      final request = AiChatRequest(
        model: 'gpt-4',
        messages: [
          AiChatMessage(role: 'user', content: 'hi', timestamp: now),
        ],
      );

      final json = request.toJson();
      expect(json.containsKey('max_tokens'), false);
      expect(json['temperature'], 0.7);
      expect(json['stream'], true);
    });
  });

  group('AiChatResponse', () {
    test('fromJson/toJson roundtrip', () {
      final json = {
        'content': 'answer',
        'model': 'gpt-4',
        'usage': {
          'prompt_tokens': 10,
          'completion_tokens': 20,
          'total_tokens': 30,
        },
      };

      final resp = AiChatResponse.fromJson(json);
      expect(resp.content, 'answer');
      expect(resp.model, 'gpt-4');
      expect(resp.promptTokens, 10);
      expect(resp.completionTokens, 20);
      expect(resp.totalTokens, 30);

      final out = resp.toJson();
      expect(out['content'], 'answer');
      expect(out['model'], 'gpt-4');
      expect((out['usage'] as Map)['prompt_tokens'], 10);
    });

    test('fromJson handles missing fields gracefully', () {
      final resp = AiChatResponse.fromJson(<String, dynamic>{});

      expect(resp.content, '');
      expect(resp.model, '');
      expect(resp.promptTokens, 0);
    });

    test('constructor defaults', () {
      const resp = AiChatResponse(content: 'x', model: 'm');

      expect(resp.promptTokens, 0);
      expect(resp.completionTokens, 0);
      expect(resp.totalTokens, 0);
    });
  });

  group('AiImageRequest', () {
    test('toJson with all optional fields', () {
      const request = AiImageRequest(
        prompt: 'a cat',
        negativePrompt: 'ugly',
        model: 'dall-e-3',
        width: 512,
        height: 512,
        count: 2,
        style: 'vivid',
        quality: 'hd',
        cfgScale: 7.5,
        steps: 30,
        seed: 42,
      );

      final json = request.toJson();
      expect(json['prompt'], 'a cat');
      expect(json['negative_prompt'], 'ugly');
      expect(json['model'], 'dall-e-3');
      expect(json['width'], 512);
      expect(json['height'], 512);
      expect(json['count'], 2);
      expect(json['style'], 'vivid');
      expect(json['quality'], 'hd');
      expect(json['cfg_scale'], 7.5);
      expect(json['steps'], 30);
      expect(json['seed'], 42);
    });

    test('toJson omits null optional fields', () {
      const request = AiImageRequest(
        prompt: 'a dog',
        model: 'dall-e-3',
      );

      final json = request.toJson();
      expect(json.containsKey('negative_prompt'), false);
      expect(json.containsKey('style'), false);
      expect(json.containsKey('quality'), false);
      expect(json.containsKey('cfg_scale'), false);
      expect(json.containsKey('steps'), false);
      expect(json.containsKey('seed'), false);
      expect(json['width'], 1024);
      expect(json['height'], 1024);
      expect(json['count'], 1);
    });
  });

  group('AiGeneratedImage', () {
    test('fromJson with url', () {
      final img = AiGeneratedImage.fromJson({
        'url': 'https://img.example.com/1.png',
        'revised_prompt': 'a cute cat',
      });

      expect(img.url, 'https://img.example.com/1.png');
      expect(img.base64, isNull);
      expect(img.revisedPrompt, 'a cute cat');
      expect(img.bytes, isNull);
    });

    test('fromJson with b64_json', () {
      final b64 = base64Encode(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]));
      final img = AiGeneratedImage.fromJson({'b64_json': b64});

      expect(img.url, isNull);
      expect(img.base64, b64);
      expect(img.bytes, isNotNull);
      expect(img.bytes!.length, 4);
      expect(img.bytes![0], 0x89);
    });

    test('fromJson with base64 key fallback', () {
      final b64 = base64Encode(Uint8List.fromList([1, 2, 3]));
      final img = AiGeneratedImage.fromJson({'base64': b64});

      expect(img.base64, b64);
      expect(img.bytes!.length, 3);
    });

    test('bytes getter caches result', () {
      final b64 = base64Encode(Uint8List.fromList([10, 20]));
      final img = AiGeneratedImage.fromJson({'b64_json': b64});

      final first = img.bytes;
      final second = img.bytes;
      expect(identical(first, second), true);
    });

    test('toJson roundtrip', () {
      final img = AiGeneratedImage(
        url: 'https://x.png',
        revisedPrompt: 'revised',
      );

      final json = img.toJson();
      expect(json['url'], 'https://x.png');
      expect(json['revised_prompt'], 'revised');
      expect(json.containsKey('b64_json'), false);
    });
  });

  group('AiImageResponse', () {
    test('fromJson with data array', () {
      final resp = AiImageResponse.fromJson({
        'data': [
          {'url': 'https://a.png'},
          {'url': 'https://b.png'},
        ],
      });

      expect(resp.images.length, 2);
      expect(resp.images[0].url, 'https://a.png');
      expect(resp.images[1].url, 'https://b.png');
    });

    test('fromJson with empty/missing data', () {
      final resp = AiImageResponse.fromJson(<String, dynamic>{});
      expect(resp.images, isEmpty);
    });

    test('toJson roundtrip', () {
      final resp = AiImageResponse(
        images: [AiGeneratedImage(url: 'https://c.png')],
      );

      final json = resp.toJson();
      final data = json['data'] as List;
      expect(data.length, 1);
      expect((data[0] as Map)['url'], 'https://c.png');
    });
  });

  group('AiVideoRequest', () {
    test('toJson with all fields', () {
      const request = AiVideoRequest(
        prompt: 'a sunset',
        model: 'gen-2',
        width: 1280,
        height: 720,
        duration: 4,
        imageUrl: 'https://ref.png',
      );

      final json = request.toJson();
      expect(json['prompt'], 'a sunset');
      expect(json['model'], 'gen-2');
      expect(json['width'], 1280);
      expect(json['height'], 720);
      expect(json['duration'], 4);
      expect(json['image_url'], 'https://ref.png');
    });

    test('toJson omits imageUrl when null', () {
      const request = AiVideoRequest(
        prompt: 'wave',
        model: 'gen-2',
        width: 1920,
        height: 1080,
        duration: 3,
      );

      final json = request.toJson();
      expect(json.containsKey('image_url'), false);
    });
  });

  group('AiVideoResponse', () {
    test('fromJson with all fields', () {
      final resp = AiVideoResponse.fromJson({
        'video_url': 'https://v.mp4',
        'task_id': 'abc-123',
        'status': 'completed',
        'error_message': 'some error',
      });

      expect(resp.videoUrl, 'https://v.mp4');
      expect(resp.taskId, 'abc-123');
      expect(resp.status, 'completed');
      expect(resp.errorMessage, 'some error');
    });

    test('fromJson defaults status to unknown', () {
      final resp = AiVideoResponse.fromJson(<String, dynamic>{});

      expect(resp.videoUrl, isNull);
      expect(resp.taskId, isNull);
      expect(resp.status, 'unknown');
      expect(resp.errorMessage, isNull);
    });

    test('fromJson reads errorMessage from "error" key as fallback', () {
      final resp = AiVideoResponse.fromJson({
        'status': 'failed',
        'error': 'generation failed',
      });

      expect(resp.errorMessage, 'generation failed');
    });

    test('toJson omits null fields', () {
      const resp = AiVideoResponse(status: 'processing');

      final json = resp.toJson();
      expect(json.containsKey('video_url'), false);
      expect(json.containsKey('task_id'), false);
      expect(json.containsKey('error_message'), false);
      expect(json['status'], 'processing');
    });

    test('toJson/fromJson roundtrip', () {
      final original = AiVideoResponse.fromJson({
        'video_url': 'https://v.mp4',
        'task_id': 't1',
        'status': 'done',
        'error_message': 'test error',
      });

      final restored = AiVideoResponse.fromJson(original.toJson());
      expect(restored.videoUrl, original.videoUrl);
      expect(restored.taskId, original.taskId);
      expect(restored.status, original.status);
      expect(restored.errorMessage, original.errorMessage);
    });
  });
}
