@TestOn('vm')
library;

import 'package:aio_studio/core/database/app_database.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late AiTaskDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = db.aiTaskDao;
  });

  tearDown(() async {
    await db.close();
  });

  int now() => DateTime.now().millisecondsSinceEpoch;

  AiTasksCompanion makeTask(
    String id, {
    String type = 'chat',
    String status = 'pending',
    String provider = 'openai',
    String? projectId,
    int? tokenUsage,
  }) {
    return AiTasksCompanion(
      id: Value(id),
      type: Value(type),
      status: Value(status),
      provider: Value(provider),
      projectId: Value(projectId),
      tokenUsage: Value(tokenUsage),
      createdAt: Value(now()),
    );
  }

  Future<void> seedProject(String id) async {
    final ts = now();
    await db.projectDao.insertProject(ProjectsCompanion(
      id: Value(id),
      name: Value('Project $id'),
      createdAt: Value(ts),
      updatedAt: Value(ts),
    ));
  }

  group('AiTaskDao', () {
    test('insertTask and getAllTasks', () async {
      await dao.insertTask(makeTask('t1'));
      await dao.insertTask(makeTask('t2'));

      final all = await dao.getAllTasks();
      expect(all, hasLength(2));
    });

    test('getTaskById returns correct task', () async {
      await dao.insertTask(makeTask('t1', provider: 'anthropic'));

      final found = await dao.getTaskById('t1');
      expect(found, isNotNull);
      expect(found!.provider, 'anthropic');

      expect(await dao.getTaskById('missing'), isNull);
    });

    test('updateTask replaces the row', () async {
      await dao.insertTask(makeTask('t1', status: 'pending'));
      final original = await dao.getTaskById('t1');

      final ok = await dao.updateTask(AiTasksCompanion(
        id: const Value('t1'),
        type: Value(original!.type),
        status: const Value('completed'),
        provider: Value(original.provider),
        createdAt: Value(original.createdAt),
      ));
      expect(ok, isTrue);

      final fetched = await dao.getTaskById('t1');
      expect(fetched!.status, 'completed');
    });

    test('deleteTask removes the row', () async {
      await dao.insertTask(makeTask('t1'));
      await dao.deleteTask('t1');
      expect(await dao.getAllTasks(), isEmpty);
    });

    test('updateTaskFields partially updates fields', () async {
      await dao.insertTask(makeTask('t1', status: 'running'));

      await dao.updateTaskFields(
        't1',
        AiTasksCompanion(
          status: const Value('completed'),
          outputText: const Value('result text'),
          completedAt: Value(now()),
        ),
      );

      final fetched = await dao.getTaskById('t1');
      expect(fetched!.status, 'completed');
      expect(fetched.outputText, 'result text');
      expect(fetched.completedAt, isNotNull);
    });

    test('filterByStatus returns matching tasks', () async {
      await dao.insertTask(makeTask('t1', status: 'pending'));
      await dao.insertTask(makeTask('t2', status: 'completed'));
      await dao.insertTask(makeTask('t3', status: 'pending'));

      final pending = await dao.filterByStatus('pending');
      expect(pending, hasLength(2));

      final completed = await dao.filterByStatus('completed');
      expect(completed, hasLength(1));
    });

    test('filterByProject and countByProject', () async {
      await seedProject('proj1');
      await dao.insertTask(makeTask('t1', projectId: 'proj1'));
      await dao.insertTask(makeTask('t2', projectId: 'proj1'));
      await dao.insertTask(makeTask('t3'));

      final byProject = await dao.filterByProject('proj1');
      expect(byProject, hasLength(2));

      expect(await dao.countByProject('proj1'), 2);
    });

    test('sumTokenUsageByProject aggregates tokens', () async {
      await seedProject('proj1');
      await dao.insertTask(
        makeTask('t1', projectId: 'proj1', tokenUsage: 100),
      );
      await dao.insertTask(
        makeTask('t2', projectId: 'proj1', tokenUsage: 250),
      );
      await dao.insertTask(
        makeTask('t3', projectId: 'proj1', tokenUsage: 50),
      );

      final total = await dao.sumTokenUsageByProject('proj1');
      expect(total, 400);
    });

    test('sumTokenUsageByProject returns 0 when no tasks', () async {
      await seedProject('empty');
      expect(await dao.sumTokenUsageByProject('empty'), 0);
    });
  });
}
