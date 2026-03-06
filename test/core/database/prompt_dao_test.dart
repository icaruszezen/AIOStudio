@TestOn('vm')
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aio_studio/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  late PromptDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = db.promptDao;
  });

  tearDown(() async {
    await db.close();
  });

  int _now() => DateTime.now().millisecondsSinceEpoch;

  PromptsCompanion _makePrompt(
    String id,
    String title, {
    String content = 'default content',
    String? category,
    String? projectId,
    bool isFavorite = false,
  }) {
    final ts = _now();
    return PromptsCompanion(
      id: Value(id),
      title: Value(title),
      content: Value(content),
      category: Value(category),
      projectId: Value(projectId),
      isFavorite: Value(isFavorite),
      createdAt: Value(ts),
      updatedAt: Value(ts),
    );
  }

  Future<void> _seedProject(String id) async {
    final ts = _now();
    await db.projectDao.insertProject(ProjectsCompanion(
      id: Value(id),
      name: Value('Project $id'),
      createdAt: Value(ts),
      updatedAt: Value(ts),
    ));
  }

  group('PromptDao', () {
    test('insertPrompt and getAllPrompts', () async {
      await dao.insertPrompt(_makePrompt('pr1', 'Translate'));
      await dao.insertPrompt(_makePrompt('pr2', 'Summarize'));

      final all = await dao.getAllPrompts();
      expect(all, hasLength(2));
    });

    test('getPromptById returns correct prompt', () async {
      await dao.insertPrompt(_makePrompt('pr1', 'Test Prompt'));

      final found = await dao.getPromptById('pr1');
      expect(found, isNotNull);
      expect(found!.title, 'Test Prompt');

      expect(await dao.getPromptById('missing'), isNull);
    });

    test('updatePrompt replaces the row', () async {
      await dao.insertPrompt(_makePrompt('pr1', 'Old'));
      final original = await dao.getPromptById('pr1');

      final ok = await dao.updatePrompt(PromptsCompanion(
        id: Value('pr1'),
        title: Value('Updated'),
        content: Value(original!.content),
        createdAt: Value(original.createdAt),
        updatedAt: Value(_now()),
      ));
      expect(ok, isTrue);

      final fetched = await dao.getPromptById('pr1');
      expect(fetched!.title, 'Updated');
    });

    test('deletePrompt removes the row', () async {
      await dao.insertPrompt(_makePrompt('pr1', 'Delete Me'));
      await dao.deletePrompt('pr1');
      expect(await dao.getAllPrompts(), isEmpty);
    });

    test('filterByCategory returns matching prompts', () async {
      await dao.insertPrompt(_makePrompt('pr1', 'A', category: 'writing'));
      await dao.insertPrompt(_makePrompt('pr2', 'B', category: 'coding'));
      await dao.insertPrompt(_makePrompt('pr3', 'C', category: 'writing'));

      final writing = await dao.filterByCategory('writing');
      expect(writing, hasLength(2));

      final coding = await dao.filterByCategory('coding');
      expect(coding, hasLength(1));
    });

    test('filterByProject returns project prompts', () async {
      await _seedProject('proj1');
      await dao.insertPrompt(_makePrompt('pr1', 'A', projectId: 'proj1'));
      await dao.insertPrompt(_makePrompt('pr2', 'B'));

      final byProject = await dao.filterByProject('proj1');
      expect(byProject, hasLength(1));
      expect(byProject.first.id, 'pr1');
    });

    test('countByProject counts correctly', () async {
      await _seedProject('proj1');
      await dao.insertPrompt(_makePrompt('pr1', 'A', projectId: 'proj1'));
      await dao.insertPrompt(_makePrompt('pr2', 'B', projectId: 'proj1'));

      expect(await dao.countByProject('proj1'), 2);
    });

    test('searchPrompts matches title or content', () async {
      await dao.insertPrompt(
        _makePrompt('pr1', 'Image generator', content: 'Create an image'),
      );
      await dao.insertPrompt(
        _makePrompt('pr2', 'Code review', content: 'Review this code'),
      );
      await dao.insertPrompt(
        _makePrompt('pr3', 'Summary', content: 'Summarize the image description'),
      );

      final byTitle = await dao.searchPrompts('generator');
      expect(byTitle, hasLength(1));

      final byContent = await dao.searchPrompts('image');
      expect(byContent, hasLength(2));
    });

    test('incrementUseCount bumps use_count by 1', () async {
      await dao.insertPrompt(_makePrompt('pr1', 'Counter'));

      final before = await dao.getPromptById('pr1');
      expect(before!.useCount, 0);

      await dao.incrementUseCount('pr1');
      await dao.incrementUseCount('pr1');

      final after = await dao.getPromptById('pr1');
      expect(after!.useCount, 2);
    });

    test('toggleFavorite flips isFavorite', () async {
      await dao.insertPrompt(_makePrompt('pr1', 'Fav'));

      await dao.toggleFavorite('pr1');
      var p = await dao.getPromptById('pr1');
      expect(p!.isFavorite, isTrue);

      await dao.toggleFavorite('pr1');
      p = await dao.getPromptById('pr1');
      expect(p!.isFavorite, isFalse);
    });

    test('duplicatePrompt creates a copy with (副本) suffix', () async {
      await dao.insertPrompt(_makePrompt('pr1', 'Original', content: 'body'));

      final newId = await dao.duplicatePrompt('pr1');
      expect(newId, isNotEmpty);
      expect(newId, isNot('pr1'));

      final copy = await dao.getPromptById(newId);
      expect(copy, isNotNull);
      expect(copy!.title, 'Original (副本)');
      expect(copy.content, 'body');

      final all = await dao.getAllPrompts();
      expect(all, hasLength(2));
    });
  });
}
