@TestOn('vm')
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:aio_studio/core/database/app_database.dart';
import 'package:aio_studio/core/providers/database_provider.dart';
import 'package:aio_studio/core/services/storage/local_storage_service.dart';
import 'package:aio_studio/features/projects/providers/projects_provider.dart';

class MockLocalStorageService extends Mock implements LocalStorageService {}

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late MockLocalStorageService mockStorage;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    mockStorage = MockLocalStorageService();

    when(() => mockStorage.deleteAssetFile(any()))
        .thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        localStorageServiceProvider.overrideWithValue(mockStorage),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<String> _createProject(String name) async {
    final actions = container.read(projectActionsProvider);
    return actions.create(name: name);
  }

  Future<String> _seedAsset(String projectId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final dao = db.assetDao;
    const id = 'asset-1';
    await dao.insertAsset(AssetsCompanion(
      id: const Value('asset-1'),
      projectId: Value(projectId),
      name: const Value('test.png'),
      type: const Value('image'),
      filePath: const Value('/fake/path/test.png'),
      sourceType: const Value('local_import'),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));
    return id;
  }

  Future<String> _seedPrompt(String projectId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    const id = 'prompt-1';
    await db.promptDao.insertPrompt(PromptsCompanion(
      id: const Value('prompt-1'),
      projectId: Value(projectId),
      title: const Value('Test Prompt'),
      content: const Value('Hello {{name}}'),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));
    return id;
  }

  Future<String> _seedTask(String projectId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    const id = 'task-1';
    await db.aiTaskDao.insertTask(AiTasksCompanion(
      id: const Value('task-1'),
      projectId: Value(projectId),
      type: const Value('chat'),
      status: const Value('completed'),
      provider: const Value('openai'),
      createdAt: Value(now),
    ));
    return id;
  }

  group('ProjectActions', () {
    test('create inserts a project and returns its id', () async {
      final id = await _createProject('My Project');

      expect(id, isNotEmpty);

      final project = await db.projectDao.getProjectById(id);
      expect(project, isNotNull);
      expect(project!.name, 'My Project');
      expect(project.isArchived, isFalse);
    });

    test('update modifies project fields', () async {
      final id = await _createProject('Original');
      final actions = container.read(projectActionsProvider);

      await actions.update(id: id, name: 'Updated', description: 'Desc');

      final project = await db.projectDao.getProjectById(id);
      expect(project!.name, 'Updated');
      expect(project.description, 'Desc');
    });

    test('archive and unarchive toggle isArchived', () async {
      final id = await _createProject('Archivable');
      final actions = container.read(projectActionsProvider);

      await actions.archive(id);
      var project = await db.projectDao.getProjectById(id);
      expect(project!.isArchived, isTrue);

      await actions.unarchive(id);
      project = await db.projectDao.getProjectById(id);
      expect(project!.isArchived, isFalse);
    });

    test('delete cascades to assets, prompts, tasks, and files', () async {
      final projectId = await _createProject('To Delete');
      final assetId = await _seedAsset(projectId);
      await _seedPrompt(projectId);
      await _seedTask(projectId);

      final actions = container.read(projectActionsProvider);
      await actions.delete(projectId);

      expect(await db.projectDao.getProjectById(projectId), isNull);
      expect(await db.assetDao.getAssetById(assetId), isNull);
      expect(await db.promptDao.filterByProject(projectId), isEmpty);
      expect(await db.aiTaskDao.filterByProject(projectId), isEmpty);

      verify(() => mockStorage.deleteAssetFile('/fake/path/test.png'))
          .called(1);
    });
  });
}
