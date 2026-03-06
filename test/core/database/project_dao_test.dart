@TestOn('vm')
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aio_studio/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  late ProjectDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = db.projectDao;
  });

  tearDown(() async {
    await db.close();
  });

  int _now() => DateTime.now().millisecondsSinceEpoch;

  ProjectsCompanion _makeProject(
    String id,
    String name, {
    bool isArchived = false,
  }) {
    final ts = _now();
    return ProjectsCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(ts),
      updatedAt: Value(ts),
      isArchived: Value(isArchived),
    );
  }

  group('ProjectDao', () {
    test('insertProject and getAllProjects', () async {
      await dao.insertProject(_makeProject('p1', 'Project One'));
      await dao.insertProject(_makeProject('p2', 'Project Two'));

      final all = await dao.getAllProjects();
      expect(all, hasLength(2));
      expect(all.map((p) => p.name), containsAll(['Project One', 'Project Two']));
    });

    test('getProjectById returns correct project', () async {
      await dao.insertProject(_makeProject('p1', 'Alpha'));

      final found = await dao.getProjectById('p1');
      expect(found, isNotNull);
      expect(found!.name, 'Alpha');

      final missing = await dao.getProjectById('nonexistent');
      expect(missing, isNull);
    });

    test('updateProject replaces the row', () async {
      final ts = _now();
      await dao.insertProject(_makeProject('p1', 'Before'));

      final original = await dao.getProjectById('p1');
      final updated = await dao.updateProject(ProjectsCompanion(
        id: Value('p1'),
        name: Value('After'),
        description: Value('desc'),
        createdAt: Value(original!.createdAt),
        updatedAt: Value(ts),
        isArchived: Value(false),
      ));
      expect(updated, isTrue);

      final fetched = await dao.getProjectById('p1');
      expect(fetched!.name, 'After');
      expect(fetched.description, 'desc');
    });

    test('toggleArchive flips isArchived flag', () async {
      await dao.insertProject(_makeProject('p1', 'Active'));

      await dao.toggleArchive('p1', archived: true);
      var p = await dao.getProjectById('p1');
      expect(p!.isArchived, isTrue);

      await dao.toggleArchive('p1', archived: false);
      p = await dao.getProjectById('p1');
      expect(p!.isArchived, isFalse);
    });

    test('searchByName finds matching projects', () async {
      await dao.insertProject(_makeProject('p1', 'Flutter App'));
      await dao.insertProject(_makeProject('p2', 'React App'));
      await dao.insertProject(_makeProject('p3', 'Dart CLI'));

      final results = await dao.searchByName('App');
      expect(results, hasLength(2));
      expect(results.map((p) => p.name), containsAll(['Flutter App', 'React App']));

      final noMatch = await dao.searchByName('Python');
      expect(noMatch, isEmpty);
    });

    test('deleteProject removes the row', () async {
      await dao.insertProject(_makeProject('p1', 'ToDelete'));

      final deleted = await dao.deleteProject('p1');
      expect(deleted, 1);

      final all = await dao.getAllProjects();
      expect(all, isEmpty);
    });

    test('watchAllProjects emits updates', () async {
      final stream = dao.watchAllProjects();

      await dao.insertProject(_makeProject('p1', 'First'));
      final firstEmit = await stream.first;
      expect(firstEmit, hasLength(1));
    });

    test('watchActiveProjects and watchArchivedProjects', () async {
      await dao.insertProject(_makeProject('p1', 'Active'));
      await dao.insertProject(_makeProject('p2', 'Archived', isArchived: true));

      final active = await dao.watchActiveProjects().first;
      expect(active, hasLength(1));
      expect(active.first.name, 'Active');

      final archived = await dao.watchArchivedProjects().first;
      expect(archived, hasLength(1));
      expect(archived.first.name, 'Archived');
    });
  });
}
