@TestOn('vm')
library;

import 'package:aio_studio/core/database/app_database.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late AiProviderConfigDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = db.aiProviderConfigDao;
  });

  tearDown(() async {
    await db.close();
  });

  int now() => DateTime.now().millisecondsSinceEpoch;

  AiProviderConfigsCompanion makeConfig(
    String id,
    String name, {
    String type = 'openai',
    bool isEnabled = true,
    String? apiKey,
    String? baseUrl,
  }) {
    final ts = now();
    return AiProviderConfigsCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      isEnabled: Value(isEnabled),
      apiKey: Value(apiKey),
      baseUrl: Value(baseUrl),
      createdAt: Value(ts),
      updatedAt: Value(ts),
    );
  }

  group('AiProviderConfigDao', () {
    test('insertConfig and getAll', () async {
      await dao.insertConfig(makeConfig('c1', 'OpenAI'));
      await dao.insertConfig(makeConfig('c2', 'Anthropic', type: 'anthropic'));

      final all = await dao.getAll();
      expect(all, hasLength(2));
      expect(all.map((c) => c.name), containsAll(['OpenAI', 'Anthropic']));
    });

    test('getById returns correct config', () async {
      await dao.insertConfig(
        makeConfig('c1', 'GPT Provider', apiKey: 'sk-test'),
      );

      final found = await dao.getById('c1');
      expect(found, isNotNull);
      expect(found!.name, 'GPT Provider');
      expect(found.apiKey, 'sk-test');

      expect(await dao.getById('nonexistent'), isNull);
    });

    test('updateConfig replaces the row', () async {
      await dao.insertConfig(makeConfig('c1', 'Old'));
      final original = await dao.getById('c1');

      final ok = await dao.updateConfig(
        AiProviderConfigsCompanion(
          id: const Value('c1'),
          name: const Value('Updated'),
          type: Value(original!.type),
          isEnabled: Value(original.isEnabled),
          createdAt: Value(original.createdAt),
          updatedAt: Value(now()),
        ),
      );
      expect(ok, isTrue);

      final fetched = await dao.getById('c1');
      expect(fetched!.name, 'Updated');
    });

    test('deleteConfig removes the row', () async {
      await dao.insertConfig(makeConfig('c1', 'Temp'));
      await dao.deleteConfig('c1');
      expect(await dao.getAll(), isEmpty);
    });

    test('getEnabled filters by isEnabled', () async {
      await dao.insertConfig(makeConfig('c1', 'Active'));
      await dao.insertConfig(makeConfig('c2', 'Disabled', isEnabled: false));
      await dao.insertConfig(makeConfig('c3', 'Also Active'));

      final enabled = await dao.getEnabled();
      expect(enabled, hasLength(2));
      expect(enabled.every((c) => c.isEnabled), isTrue);
    });

    test('getByType filters by provider type', () async {
      await dao.insertConfig(makeConfig('c1', 'GPT-4', type: 'openai'));
      await dao.insertConfig(makeConfig('c2', 'Claude', type: 'anthropic'));
      await dao.insertConfig(makeConfig('c3', 'GPT-3', type: 'openai'));

      final openai = await dao.getByType('openai');
      expect(openai, hasLength(2));

      final anthropic = await dao.getByType('anthropic');
      expect(anthropic, hasLength(1));
      expect(anthropic.first.name, 'Claude');
    });

    test('getByType returns empty for unknown type', () async {
      await dao.insertConfig(makeConfig('c1', 'X', type: 'openai'));
      expect(await dao.getByType('gemini'), isEmpty);
    });

    test('full lifecycle: insert -> query -> update -> delete', () async {
      await dao.insertConfig(
        makeConfig(
          'c1',
          'Provider',
          type: 'openai',
          baseUrl: 'https://api.openai.com',
        ),
      );

      var config = await dao.getById('c1');
      expect(config!.baseUrl, 'https://api.openai.com');

      await dao.updateConfig(
        AiProviderConfigsCompanion(
          id: const Value('c1'),
          name: const Value('Provider v2'),
          type: const Value('openai'),
          baseUrl: const Value('https://api.openai.com/v2'),
          isEnabled: const Value(true),
          createdAt: Value(config.createdAt),
          updatedAt: Value(now()),
        ),
      );

      config = await dao.getById('c1');
      expect(config!.name, 'Provider v2');
      expect(config.baseUrl, 'https://api.openai.com/v2');

      await dao.deleteConfig('c1');
      expect(await dao.getAll(), isEmpty);
    });
  });
}
