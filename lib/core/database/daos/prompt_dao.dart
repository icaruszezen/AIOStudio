import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/prompts.dart';

part 'prompt_dao.g.dart';

@DriftAccessor(tables: [Prompts])
class PromptDao extends DatabaseAccessor<AppDatabase> with _$PromptDaoMixin {
  PromptDao(super.db);

  Future<List<Prompt>> getAllPrompts() => select(prompts).get();

  Stream<List<Prompt>> watchAllPrompts() => select(prompts).watch();

  Future<Prompt?> getPromptById(String id) =>
      (select(prompts)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertPrompt(PromptsCompanion entry) =>
      into(prompts).insert(entry);

  Future<bool> updatePrompt(PromptsCompanion entry) =>
      update(prompts).replace(entry);

  Future<int> deletePrompt(String id) =>
      (delete(prompts)..where((t) => t.id.equals(id))).go();

  Future<List<Prompt>> filterByCategory(String category) =>
      (select(prompts)..where((t) => t.category.equals(category))).get();

  Future<void> incrementUseCount(String id) async {
    final prompt = await getPromptById(id);
    if (prompt != null) {
      await (update(prompts)..where((t) => t.id.equals(id))).write(
        PromptsCompanion(useCount: Value(prompt.useCount + 1)),
      );
    }
  }

  Future<List<Prompt>> filterByProject(String projectId) =>
      (select(prompts)..where((t) => t.projectId.equals(projectId))).get();

  Future<int> countByProject(String projectId) async {
    final count = countAll();
    final query = selectOnly(prompts)..addColumns([count]);
    query.where(prompts.projectId.equals(projectId));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }
}
