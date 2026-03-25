@TestOn('vm')
library;

import 'dart:convert';

import 'package:aio_studio/core/database/app_database.dart';
import 'package:aio_studio/core/services/ai/ai_models.dart';
import 'package:aio_studio/core/services/ai/ai_service_manager.dart';
import 'package:aio_studio/core/services/secure_key_service.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSecureKeyService extends Mock implements SecureKeyService {}

void main() {
  late AppDatabase db;
  late AiProviderConfigDao dao;
  late MockSecureKeyService mockKeys;
  late AiServiceManager manager;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = db.aiProviderConfigDao;
    mockKeys = MockSecureKeyService();
    manager = AiServiceManager(dao: dao, secureKeys: mockKeys);
  });

  tearDown(() async {
    manager.disposeAll();
    await db.close();
  });

  int now() => DateTime.now().millisecondsSinceEpoch;

  Future<void> insertConfig({
    required String id,
    required String name,
    required String type,
    String? baseUrl,
    String? apiKey,
    String? defaultModel,
    bool isEnabled = true,
    String? extraConfig,
  }) async {
    final ts = now();
    await dao.insertConfig(AiProviderConfigsCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      baseUrl: Value(baseUrl),
      apiKey: Value(apiKey),
      defaultModel: Value(defaultModel),
      isEnabled: Value(isEnabled),
      extraConfig: Value(extraConfig),
      createdAt: Value(ts),
      updatedAt: Value(ts),
    ));
  }

  group('AiServiceManager', () {
    test('loadServices creates services for enabled configs', () async {
      when(() => mockKeys.getApiKey(any())).thenAnswer((_) async => 'sk-test');

      await insertConfig(
        id: 'openai-1',
        name: 'OpenAI',
        type: 'openai',
        baseUrl: 'https://api.openai.com',
      );
      await insertConfig(
        id: 'anthropic-1',
        name: 'Anthropic',
        type: 'anthropic',
        baseUrl: 'https://api.anthropic.com',
      );

      await manager.loadServices();

      expect(manager.getService('openai-1'), isNotNull);
      expect(manager.getService('anthropic-1'), isNotNull);
      expect(manager.getAllEnabledServices(), hasLength(2));
    });

    test('loadServices ignores disabled configs', () async {
      when(() => mockKeys.getApiKey(any())).thenAnswer((_) async => 'sk-test');

      await insertConfig(
        id: 'enabled',
        name: 'Enabled',
        type: 'openai',
        isEnabled: true,
      );
      await insertConfig(
        id: 'disabled',
        name: 'Disabled',
        type: 'openai',
        isEnabled: false,
      );

      await manager.loadServices();

      expect(manager.getService('enabled'), isNotNull);
      expect(manager.getService('disabled'), isNull);
    });

    test('loadServices uses secure key over config apiKey', () async {
      when(() => mockKeys.getApiKey('prov-1'))
          .thenAnswer((_) async => 'secure-key');

      await insertConfig(
        id: 'prov-1',
        name: 'Test',
        type: 'openai',
        apiKey: 'plain-key',
      );

      await manager.loadServices();

      verify(() => mockKeys.getApiKey('prov-1')).called(1);
      expect(manager.getService('prov-1'), isNotNull);
    });

    test('loadServices falls back to config apiKey when secure key is null',
        () async {
      when(() => mockKeys.getApiKey(any())).thenAnswer((_) async => null);

      await insertConfig(
        id: 'prov-1',
        name: 'Test',
        type: 'openai',
        apiKey: 'fallback-key',
      );

      await manager.loadServices();
      expect(manager.getService('prov-1'), isNotNull);
    });

    test('loadServices replaces previous services on re-call', () async {
      when(() => mockKeys.getApiKey(any())).thenAnswer((_) async => 'key');

      await insertConfig(id: 'p1', name: 'P1', type: 'openai');
      await manager.loadServices();
      expect(manager.getAllEnabledServices(), hasLength(1));

      await insertConfig(id: 'p2', name: 'P2', type: 'anthropic');
      await manager.loadServices();
      expect(manager.getAllEnabledServices(), hasLength(2));
    });

    test('loadServices skips custom provider without baseUrl', () async {
      when(() => mockKeys.getApiKey(any())).thenAnswer((_) async => 'key');

      await insertConfig(
        id: 'custom-1',
        name: 'Custom No URL',
        type: 'custom',
        baseUrl: null,
      );

      await manager.loadServices();
      expect(manager.getService('custom-1'), isNull);
    });

    test('loadServices creates custom service with valid baseUrl', () async {
      when(() => mockKeys.getApiKey(any())).thenAnswer((_) async => 'key');

      await insertConfig(
        id: 'custom-1',
        name: 'My Custom',
        type: 'custom',
        baseUrl: 'https://my-api.example.com',
        defaultModel: 'my-model',
      );

      await manager.loadServices();
      final service = manager.getService('custom-1');
      expect(service, isNotNull);
      expect(service!.providerName, 'My Custom');
    });

    test('loadServices skips unknown provider type', () async {
      when(() => mockKeys.getApiKey(any())).thenAnswer((_) async => 'key');

      await insertConfig(
        id: 'unknown-1',
        name: 'Unknown',
        type: 'gemini',
      );

      await manager.loadServices();
      expect(manager.getService('unknown-1'), isNull);
    });

    test('getService returns null for nonexistent id', () {
      expect(manager.getService('nonexistent'), isNull);
    });

    test('getDefaultChatService returns first chat-capable service', () async {
      when(() => mockKeys.getApiKey(any())).thenAnswer((_) async => 'key');

      await insertConfig(id: 'oai', name: 'OpenAI', type: 'openai');
      await manager.loadServices();

      expect(manager.getDefaultChatService(), isNotNull);
      expect(manager.getDefaultChatService()!.supportsChatCompletion, isTrue);
    });

    test('getDefaultImageService returns null when no image service', () async {
      when(() => mockKeys.getApiKey(any())).thenAnswer((_) async => 'key');

      await insertConfig(id: 'anthropic', name: 'Anthropic', type: 'anthropic');
      await manager.loadServices();

      expect(manager.getDefaultImageService(), isNull);
    });

    test('getDefaultVideoService returns null when no video service', () async {
      when(() => mockKeys.getApiKey(any())).thenAnswer((_) async => 'key');

      await insertConfig(id: 'oai', name: 'OpenAI', type: 'openai');
      await manager.loadServices();

      expect(manager.getDefaultVideoService(), isNull);
    });

    test('getAvailableModels returns models for given type', () async {
      when(() => mockKeys.getApiKey(any())).thenAnswer((_) async => 'key');

      await insertConfig(id: 'oai', name: 'OpenAI', type: 'openai');
      await manager.loadServices();

      final chatModels = manager.getAvailableModels('chat');
      expect(chatModels, isNotEmpty);

      final unknownModels = manager.getAvailableModels('unknown_type');
      expect(unknownModels, isEmpty);
    });

    test('getAvailableModelInfos filters by type', () async {
      when(() => mockKeys.getApiKey(any())).thenAnswer((_) async => 'key');

      final discoveredModels = [
        AiModelInfo(id: 'gpt-4o', mode: 'chat').toJson(),
        AiModelInfo(id: 'dall-e-3', mode: 'image_generation').toJson(),
      ];

      await insertConfig(
        id: 'oai',
        name: 'OpenAI',
        type: 'openai',
        extraConfig: jsonEncode({
          'discovered_models': discoveredModels,
        }),
      );
      await manager.loadServices();

      final chatInfos = manager.getAvailableModelInfos('chat');
      expect(chatInfos.any((m) => m.id == 'gpt-4o'), isTrue);

      final imageInfos = manager.getAvailableModelInfos('image');
      expect(imageInfos.any((m) => m.id == 'dall-e-3'), isTrue);
    });

    test('disposeAll clears all services', () async {
      when(() => mockKeys.getApiKey(any())).thenAnswer((_) async => 'key');

      await insertConfig(id: 'oai', name: 'OpenAI', type: 'openai');
      await manager.loadServices();
      expect(manager.getAllEnabledServices(), isNotEmpty);

      manager.disposeAll();
      expect(manager.getAllEnabledServices(), isEmpty);
      expect(manager.getService('oai'), isNull);
    });

    test('stability service is created correctly', () async {
      when(() => mockKeys.getApiKey(any())).thenAnswer((_) async => 'key');

      await insertConfig(
        id: 'stab-1',
        name: 'Stability',
        type: 'stability',
      );
      await manager.loadServices();

      final service = manager.getService('stab-1');
      expect(service, isNotNull);
      expect(service!.supportsImageGeneration, isTrue);
    });
  });
}
