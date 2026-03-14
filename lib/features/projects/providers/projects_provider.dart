import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';

export '../../../core/providers/database_provider.dart'
    show activeProjectsProvider;

// ---------------------------------------------------------------------------
// Stream providers
// ---------------------------------------------------------------------------

final archivedProjectsProvider = StreamProvider<List<Project>>((ref) {
  return ref.watch(projectDaoProvider).watchArchivedProjects();
});

final projectDetailProvider =
    StreamProvider.family<Project?, String>((ref, id) {
  return ref.watch(projectDaoProvider).watchProjectById(id);
});

final projectAiTasksProvider =
    StreamProvider.family<List<AiTask>, String>((ref, projectId) {
  return ref.watch(aiTaskDaoProvider).watchByProject(projectId);
});

// ---------------------------------------------------------------------------
// Future providers
// ---------------------------------------------------------------------------

final searchProjectsProvider =
    FutureProvider.family<List<Project>, String>((ref, query) {
  if (query.isEmpty) return Future.value([]);
  return ref.watch(projectDaoProvider).searchByName(query);
});

final projectStatsProvider =
    FutureProvider.family<ProjectStats, String>((ref, projectId) async {
  final assetDao = ref.watch(assetDaoProvider);
  final promptDao = ref.watch(promptDaoProvider);
  final aiTaskDao = ref.watch(aiTaskDaoProvider);

  final results = await Future.wait([
    assetDao.countByProject(projectId),
    assetDao.countByProjectAndType(projectId, 'image'),
    assetDao.countByProjectAndType(projectId, 'video'),
    promptDao.countByProject(projectId),
    aiTaskDao.countByProject(projectId),
    aiTaskDao.sumTokenUsageByProject(projectId),
  ]);

  return ProjectStats(
    totalAssets: results[0],
    imageCount: results[1],
    videoCount: results[2],
    promptCount: results[3],
    aiTaskCount: results[4],
    totalTokenUsage: results[5],
  );
});

// ---------------------------------------------------------------------------
// Project actions (CRUD)
// ---------------------------------------------------------------------------

final projectActionsProvider = Provider<ProjectActions>((ref) {
  return ProjectActions(ref);
});

class ProjectActions {
  ProjectActions(this._ref);

  final Ref _ref;
  static const _uuid = Uuid();

  Future<String> create({
    required String name,
    String? description,
    String? coverImagePath,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _ref.read(projectDaoProvider).insertProject(
          ProjectsCompanion.insert(
            id: id,
            name: name,
            description: Value(description),
            coverImagePath: Value(coverImagePath),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> update({
    required String id,
    String? name,
    String? description,
    String? coverImagePath,
    bool clearCover = false,
  }) async {
    final dao = _ref.read(projectDaoProvider);
    final existing = await dao.getProjectById(id);
    if (existing == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    await dao.updateProject(
      ProjectsCompanion(
        id: Value(existing.id),
        name: Value(name ?? existing.name),
        description: Value(description ?? existing.description),
        coverImagePath: Value(
          clearCover ? null : (coverImagePath ?? existing.coverImagePath),
        ),
        createdAt: Value(existing.createdAt),
        updatedAt: Value(now),
        isArchived: Value(existing.isArchived),
      ),
    );
  }

  Future<void> archive(String id) =>
      _ref.read(projectDaoProvider).toggleArchive(id, archived: true);

  Future<void> unarchive(String id) =>
      _ref.read(projectDaoProvider).toggleArchive(id, archived: false);

  Future<void> delete(String id) async {
    final db = _ref.read(appDatabaseProvider);
    final assetDao = _ref.read(assetDaoProvider);
    final promptDao = _ref.read(promptDaoProvider);
    final aiTaskDao = _ref.read(aiTaskDaoProvider);
    final projectDao = _ref.read(projectDaoProvider);
    final storage = _ref.read(localStorageServiceProvider);

    final assets = await assetDao.getByProject(id);

    await db.transaction(() async {
      for (final asset in assets) {
        await assetDao.deleteAsset(asset.id);
      }

      final prompts = await promptDao.filterByProject(id);
      for (final prompt in prompts) {
        await promptDao.deletePrompt(prompt.id);
      }

      final tasks = await aiTaskDao.filterByProject(id);
      for (final task in tasks) {
        await aiTaskDao.deleteTask(task.id);
      }

      await projectDao.deleteProject(id);
    });

    for (final asset in assets) {
      if (asset.sourceType != 'local_import') {
        await storage.deleteAssetFile(asset.filePath);
      }
      if (asset.thumbnailPath != null) {
        await storage.deleteAssetFile(asset.thumbnailPath!);
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Stats model
// ---------------------------------------------------------------------------

class ProjectStats {
  const ProjectStats({
    required this.totalAssets,
    required this.imageCount,
    required this.videoCount,
    required this.promptCount,
    required this.aiTaskCount,
    required this.totalTokenUsage,
  });

  final int totalAssets;
  final int imageCount;
  final int videoCount;
  final int promptCount;
  final int aiTaskCount;
  final int totalTokenUsage;
}
