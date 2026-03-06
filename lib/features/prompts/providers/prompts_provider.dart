import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/ai_providers.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/services/ai/ai_models.dart';

// ---------------------------------------------------------------------------
// Stream providers
// ---------------------------------------------------------------------------

final allPromptsProvider = StreamProvider<List<Prompt>>((ref) {
  return ref.watch(promptDaoProvider).watchPrompts();
});

final promptsByCategoryProvider =
    StreamProvider.family<List<Prompt>, String>((ref, category) {
  return ref.watch(promptDaoProvider).watchPrompts(category: category);
});

final promptsByProjectProvider =
    StreamProvider.family<List<Prompt>, String>((ref, projectId) {
  return ref.watch(promptDaoProvider).watchPrompts(projectId: projectId);
});

final favoritePromptsProvider = StreamProvider<List<Prompt>>((ref) {
  return ref.watch(promptDaoProvider).watchFavoritePrompts();
});

// ---------------------------------------------------------------------------
// Future providers
// ---------------------------------------------------------------------------

final searchPromptsProvider =
    FutureProvider.family<List<Prompt>, String>((ref, query) {
  if (query.isEmpty) return Future.value([]);
  return ref.watch(promptDaoProvider).searchPrompts(query);
});

final promptDetailProvider =
    StreamProvider.family<Prompt?, String>((ref, id) {
  return ref.watch(promptDaoProvider).watchPromptById(id);
});

// ---------------------------------------------------------------------------
// State providers
// ---------------------------------------------------------------------------

final currentPromptIdProvider =
    NotifierProvider<CurrentPromptIdNotifier, String?>(
  CurrentPromptIdNotifier.new,
);

class CurrentPromptIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

final promptCategoryFilterProvider =
    NotifierProvider<_CategoryFilterNotifier, String?>(
  _CategoryFilterNotifier.new,
);

class _CategoryFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? category) => state = category;
}

final promptSearchQueryProvider =
    NotifierProvider<_SearchQueryNotifier, String>(
  _SearchQueryNotifier.new,
);

class _SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String query) => state = query;
}

/// Combined provider: applies category filter and search to the full list.
final filteredPromptsProvider = StreamProvider<List<Prompt>>((ref) {
  final category = ref.watch(promptCategoryFilterProvider);
  final query = ref.watch(promptSearchQueryProvider);

  if (query.isNotEmpty) {
    return ref.watch(promptDaoProvider).watchSearchPrompts(query);
  }

  return ref.watch(promptDaoProvider).watchPrompts(category: category);
});

// ---------------------------------------------------------------------------
// Prompt actions
// ---------------------------------------------------------------------------

final promptActionsProvider = Provider<PromptActions>((ref) {
  return PromptActions(ref);
});

class PromptActions {
  PromptActions(this._ref);

  static const _uuid = Uuid();
  final Ref _ref;

  Future<String> createPrompt({
    required String title,
    required String content,
    String? category,
    String? variables,
    String? projectId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _uuid.v4();
    await _ref.read(promptDaoProvider).insertPrompt(
          PromptsCompanion(
            id: Value(id),
            projectId: Value(projectId),
            title: Value(title),
            content: Value(content),
            category: Value(category),
            variables: Value(variables),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return id;
  }

  Future<void> updatePrompt({
    required String id,
    String? title,
    String? content,
    String? category,
    String? variables,
    String? projectId,
    bool clearProject = false,
  }) async {
    final dao = _ref.read(promptDaoProvider);
    final existing = await dao.getPromptById(id);
    if (existing == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    await dao.updatePrompt(
      PromptsCompanion(
        id: Value(existing.id),
        projectId:
            Value(clearProject ? null : (projectId ?? existing.projectId)),
        title: Value(title ?? existing.title),
        content: Value(content ?? existing.content),
        category: Value(category ?? existing.category),
        variables: Value(variables ?? existing.variables),
        isFavorite: Value(existing.isFavorite),
        useCount: Value(existing.useCount),
        createdAt: Value(existing.createdAt),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> deletePrompt(String id) async {
    await _ref.read(promptDaoProvider).deletePrompt(id);
    final currentId = _ref.read(currentPromptIdProvider);
    if (currentId == id) {
      _ref.read(currentPromptIdProvider.notifier).select(null);
    }
  }

  Future<void> toggleFavorite(String id) async {
    await _ref.read(promptDaoProvider).toggleFavorite(id);
  }

  Future<void> incrementUseCount(String id) async {
    await _ref.read(promptDaoProvider).incrementUseCount(id);
  }

  Future<String> duplicatePrompt(String id) async {
    return _ref.read(promptDaoProvider).duplicatePrompt(id);
  }

  Future<String> optimizePrompt(String content, String? category) async {
    final service = _ref.read(defaultChatServiceProvider);
    if (service == null) {
      throw StateError('未配置 AI 聊天服务，请先在设置中添加 AI 服务。');
    }

    final models =
        await _ref.read(availableModelsProvider('chat').future);
    if (models.isEmpty) {
      throw StateError('无可用的聊天模型，请先在设置中配置 AI 服务。');
    }
    final model = models.first;

    final categoryLabel = _categoryDisplayName(category);
    final systemPrompt =
        '你是一个提示词工程专家。请优化以下提示词，使其更清晰、具体、有效。'
        '保持用户的核心意图不变，但改善表达方式、添加必要的约束和上下文。'
        '分类为 $categoryLabel。直接返回优化后的提示词，不需要解释。';

    final request = AiChatRequest(
      messages: [
        AiChatMessage(
          role: 'system',
          content: systemPrompt,
          timestamp: DateTime.now(),
        ),
        AiChatMessage(
          role: 'user',
          content: content,
          timestamp: DateTime.now(),
        ),
      ],
      model: model,
      stream: false,
      maxTokens: 2048,
    );

    final response = await service.chatCompletion(request);
    return response.content;
  }

  static String _categoryDisplayName(String? category) {
    if (category == null) return '通用';
    for (final c in promptCategories) {
      if (c.value == category) return c.label;
    }
    return '通用';
  }
}

// ---------------------------------------------------------------------------
// Category helpers
// ---------------------------------------------------------------------------

class PromptCategoryInfo {
  const PromptCategoryInfo(this.value, this.label);
  final String value;
  final String label;
}

const promptCategories = [
  PromptCategoryInfo('text_gen', '文本生成'),
  PromptCategoryInfo('image_gen', '图片生成'),
  PromptCategoryInfo('video_gen', '视频生成'),
  PromptCategoryInfo('optimization', '优化'),
  PromptCategoryInfo('other', '其他'),
];
