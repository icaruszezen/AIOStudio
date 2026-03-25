@TestOn('vm')
library;

import 'package:aio_studio/core/database/app_database.dart';
import 'package:aio_studio/core/providers/database_provider.dart';
import 'package:aio_studio/features/prompts/providers/prompts_provider.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('PromptActions', () {
    test('createPrompt inserts a prompt and returns its id', () async {
      final actions = container.read(promptActionsProvider);

      final id = await actions.createPrompt(
        title: 'Test Prompt',
        content: 'Hello {{name}}',
        category: 'chat',
      );

      expect(id, isNotEmpty);
      final prompt = await db.promptDao.getPromptById(id);
      expect(prompt, isNotNull);
      expect(prompt!.title, 'Test Prompt');
      expect(prompt.content, 'Hello {{name}}');
      expect(prompt.category, 'chat');
    });

    test('createPrompt with projectId associates to project', () async {
      final ts = DateTime.now().millisecondsSinceEpoch;
      await db.projectDao.insertProject(ProjectsCompanion(
        id: const Value('proj-1'),
        name: const Value('Test'),
        createdAt: Value(ts),
        updatedAt: Value(ts),
      ));

      final actions = container.read(promptActionsProvider);
      final id = await actions.createPrompt(
        title: 'Project Prompt',
        content: 'content',
        projectId: 'proj-1',
      );

      final prompt = await db.promptDao.getPromptById(id);
      expect(prompt!.projectId, 'proj-1');
    });

    test('updatePrompt modifies title and content', () async {
      final actions = container.read(promptActionsProvider);
      final id = await actions.createPrompt(
        title: 'Original',
        content: 'old content',
      );

      await actions.updatePrompt(
        id: id,
        title: 'Updated',
        content: 'new content',
      );

      final prompt = await db.promptDao.getPromptById(id);
      expect(prompt!.title, 'Updated');
      expect(prompt.content, 'new content');
    });

    test('updatePrompt preserves unchanged fields', () async {
      final actions = container.read(promptActionsProvider);
      final id = await actions.createPrompt(
        title: 'Keep Me',
        content: 'keep this',
        category: 'image_gen',
      );

      await actions.updatePrompt(id: id, title: 'New Title');

      final prompt = await db.promptDao.getPromptById(id);
      expect(prompt!.title, 'New Title');
      expect(prompt.content, 'keep this');
      expect(prompt.category, 'image_gen');
    });

    test('deletePrompt removes the prompt', () async {
      final actions = container.read(promptActionsProvider);
      final id = await actions.createPrompt(
        title: 'To Delete',
        content: 'bye',
      );

      await actions.deletePrompt(id);
      expect(await db.promptDao.getPromptById(id), isNull);
    });

    test('deletePrompt clears currentPromptId if matching', () async {
      final actions = container.read(promptActionsProvider);
      final id = await actions.createPrompt(
        title: 'Selected',
        content: 'content',
      );

      container.read(currentPromptIdProvider.notifier).select(id);
      expect(container.read(currentPromptIdProvider), id);

      await actions.deletePrompt(id);
      expect(container.read(currentPromptIdProvider), isNull);
    });

    test('toggleFavorite flips the flag', () async {
      final actions = container.read(promptActionsProvider);
      final id = await actions.createPrompt(
        title: 'Fav',
        content: 'content',
      );

      var prompt = await db.promptDao.getPromptById(id);
      expect(prompt!.isFavorite, isFalse);

      await actions.toggleFavorite(id);
      prompt = await db.promptDao.getPromptById(id);
      expect(prompt!.isFavorite, isTrue);

      await actions.toggleFavorite(id);
      prompt = await db.promptDao.getPromptById(id);
      expect(prompt!.isFavorite, isFalse);
    });

    test('incrementUseCount bumps count by 1', () async {
      final actions = container.read(promptActionsProvider);
      final id = await actions.createPrompt(
        title: 'Used',
        content: 'content',
      );

      var prompt = await db.promptDao.getPromptById(id);
      expect(prompt!.useCount, 0);

      await actions.incrementUseCount(id);
      prompt = await db.promptDao.getPromptById(id);
      expect(prompt!.useCount, 1);

      await actions.incrementUseCount(id);
      await actions.incrementUseCount(id);
      prompt = await db.promptDao.getPromptById(id);
      expect(prompt!.useCount, 3);
    });

    test('duplicatePrompt creates a copy', () async {
      final actions = container.read(promptActionsProvider);
      final originalId = await actions.createPrompt(
        title: 'Original',
        content: 'original content',
        category: 'chat',
      );

      final copyId = await actions.duplicatePrompt(originalId);
      expect(copyId, isNot(originalId));

      final copy = await db.promptDao.getPromptById(copyId);
      expect(copy, isNotNull);
      expect(copy!.content, 'original content');
      expect(copy.category, 'chat');
    });
  });

  group('Prompt filter notifiers', () {
    test('CurrentPromptIdNotifier select and clear', () {
      final notifier = container.read(currentPromptIdProvider.notifier);
      expect(container.read(currentPromptIdProvider), isNull);

      notifier.select('prompt-1');
      expect(container.read(currentPromptIdProvider), 'prompt-1');

      notifier.select(null);
      expect(container.read(currentPromptIdProvider), isNull);
    });

    test('promptSearchQueryProvider default is empty', () {
      expect(container.read(promptSearchQueryProvider), '');
    });

    test('promptFavoriteFilterProvider default is false', () {
      expect(container.read(promptFavoriteFilterProvider), isFalse);
    });
  });

  group('PromptCategoryInfo', () {
    test('promptCategories contains expected categories', () {
      expect(promptCategories, isNotEmpty);
      expect(
        promptCategories.map((c) => c.value),
        containsAll(['text_gen', 'image_gen', 'chat']),
      );
    });
  });
}
