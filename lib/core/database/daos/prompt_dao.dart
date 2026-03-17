import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../utils/epoch_utils.dart';
import '../../utils/query_utils.dart';
import '../app_database.dart';
import '../tables/prompts.dart';

part 'prompt_dao.g.dart';

@DriftAccessor(tables: [Prompts])
class PromptDao extends DatabaseAccessor<AppDatabase> with _$PromptDaoMixin {
  PromptDao(super.db);

  Future<List<Prompt>> getAllPrompts() => select(prompts).get();

  Stream<List<Prompt>> watchAllPrompts() => select(prompts).watch();

  Stream<List<Prompt>> watchPrompts({String? projectId, String? category}) {
    final query = select(prompts)
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    if (projectId != null) {
      query.where((t) => t.projectId.equals(projectId));
    }
    if (category != null) {
      query.where((t) => t.category.equals(category));
    }
    return query.watch();
  }

  Stream<List<Prompt>> watchFavoritePrompts() {
    return (select(prompts)
          ..where((t) => t.isFavorite.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }

  Future<Prompt?> getPromptById(String id) =>
      (select(prompts)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<Prompt?> watchPromptById(String id) =>
      (select(prompts)..where((t) => t.id.equals(id)))
          .watchSingleOrNull();

  Future<int> insertPrompt(PromptsCompanion entry) =>
      into(prompts).insert(entry);

  Future<bool> updatePrompt(PromptsCompanion entry) =>
      update(prompts).replace(entry);

  Future<int> deletePrompt(String id) =>
      (delete(prompts)..where((t) => t.id.equals(id))).go();

  Future<int> deleteByProject(String projectId) =>
      (delete(prompts)..where((t) => t.projectId.equals(projectId))).go();

  Future<List<Prompt>> filterByCategory(String category) =>
      (select(prompts)..where((t) => t.category.equals(category))).get();

  Future<void> incrementUseCount(String id) async {
    await customUpdate(
      'UPDATE prompts SET use_count = use_count + 1 WHERE id = ?',
      variables: [Variable.withString(id)],
      updates: {prompts},
    );
  }

  Future<List<Prompt>> filterByProject(String projectId) =>
      (select(prompts)..where((t) => t.projectId.equals(projectId))).get();

  Future<int> countByProject(String projectId) async {
    final count = countAll();
    final query = selectOnly(prompts)
      ..addColumns([count])
      ..where(prompts.projectId.equals(projectId));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  Future<List<Prompt>> searchPrompts(String query) => (select(prompts)
        ..where(
            (t) => likeEscaped(t.title, query) | likeEscaped(t.content, query))
        ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
      .get();

  Stream<List<Prompt>> watchSearchPrompts(
    String query, {
    String? category,
    bool favoritesOnly = false,
  }) {
    final q = select(prompts)
      ..where(
          (t) => likeEscaped(t.title, query) | likeEscaped(t.content, query))
      ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    if (category != null) {
      q.where((t) => t.category.equals(category));
    }
    if (favoritesOnly) {
      q.where((t) => t.isFavorite.equals(true));
    }
    return q.watch();
  }

  Future<void> toggleFavorite(String id) async {
    await customUpdate(
      'UPDATE prompts SET is_favorite = NOT is_favorite WHERE id = ?',
      variables: [Variable.withString(id)],
      updates: {prompts},
    );
  }

  static const _uuid = Uuid();

  Future<String> duplicatePrompt(String id) async {
    final prompt = await getPromptById(id);
    if (prompt == null) throw StateError('Prompt $id not found');
    final now = epochNowMs();
    final newId = _uuid.v4();
    await insertPrompt(PromptsCompanion(
      id: Value(newId),
      projectId: Value(prompt.projectId),
      title: Value('${prompt.title} (副本)'),
      content: Value(prompt.content),
      category: Value(prompt.category),
      variables: Value(prompt.variables),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));
    return newId;
  }
}
