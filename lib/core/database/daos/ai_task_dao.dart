import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/ai_tasks.dart';

part 'ai_task_dao.g.dart';

@DriftAccessor(tables: [AiTasks])
class AiTaskDao extends DatabaseAccessor<AppDatabase> with _$AiTaskDaoMixin {
  AiTaskDao(super.db);

  Future<List<AiTask>> getAllTasks() => select(aiTasks).get();

  Stream<List<AiTask>> watchAllTasks() => select(aiTasks).watch();

  Future<AiTask?> getTaskById(String id) =>
      (select(aiTasks)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertTask(AiTasksCompanion entry) =>
      into(aiTasks).insert(entry);

  Future<bool> updateTask(AiTasksCompanion entry) =>
      update(aiTasks).replace(entry);

  Future<int> deleteTask(String id) =>
      (delete(aiTasks)..where((t) => t.id.equals(id))).go();

  Future<int> deleteByProject(String projectId) =>
      (delete(aiTasks)..where((t) => t.projectId.equals(projectId))).go();

  /// Sets `outputAssetId` to NULL for any tasks referencing the given assets,
  /// so the asset rows can be safely deleted without violating FK constraints.
  Future<void> nullifyOutputAssetIds(List<String> assetIds) =>
      (update(aiTasks)..where((t) => t.outputAssetId.isIn(assetIds)))
          .write(AiTasksCompanion(outputAssetId: Value(null)));

  Future<void> updateTaskFields(String id, AiTasksCompanion entry) =>
      (update(aiTasks)..where((t) => t.id.equals(id))).write(entry);

  Stream<List<AiTask>> watchByType(String type) => (select(aiTasks)
        ..where((t) => t.type.equals(type))
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .watch();

  Future<List<AiTask>> filterByStatus(String status) =>
      (select(aiTasks)..where((t) => t.status.equals(status))).get();

  Future<List<AiTask>> filterByProject(String projectId) =>
      (select(aiTasks)..where((t) => t.projectId.equals(projectId))).get();

  Stream<List<AiTask>> watchByProject(String projectId) =>
      (select(aiTasks)..where((t) => t.projectId.equals(projectId))).watch();

  Future<int> countByProject(String projectId) async {
    final count = countAll();
    final query = selectOnly(aiTasks)
      ..addColumns([count])
      ..where(aiTasks.projectId.equals(projectId));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  Future<int> sumTokenUsageByProject(String projectId) async {
    final sum = aiTasks.tokenUsage.sum();
    final query = selectOnly(aiTasks)
      ..addColumns([sum])
      ..where(aiTasks.projectId.equals(projectId));
    final result = await query.getSingle();
    return result.read(sum) ?? 0;
  }
}
