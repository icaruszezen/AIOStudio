import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/utils/epoch_utils.dart';

export '../../../core/providers/database_provider.dart'
    show activeProjectsProvider;

// ---------------------------------------------------------------------------
// Stream providers
// ---------------------------------------------------------------------------

final archivedProjectsProvider = StreamProvider<List<Project>>((ref) {
  return ref.watch(projectDaoProvider).watchArchivedProjects();
});

final projectDetailProvider = StreamProvider.autoDispose
    .family<Project?, String>((ref, id) {
      return ref.watch(projectDaoProvider).watchProjectById(id);
    });

final projectAiTasksProvider = StreamProvider.autoDispose
    .family<List<AiTask>, String>((ref, projectId) {
      return ref.watch(aiTaskDaoProvider).watchByProject(projectId);
    });

// ---------------------------------------------------------------------------
// Future providers
// ---------------------------------------------------------------------------

final searchProjectsProvider = FutureProvider.autoDispose
    .family<List<Project>, (String query, bool archivedOnly)>((ref, params) {
      final (query, archivedOnly) = params;
      if (query.isEmpty) return Future.value([]);
      return ref
          .watch(projectDaoProvider)
          .searchByName(query, archivedOnly: archivedOnly);
    });

/// Lightweight count-only streams for reactive stats updates.
final _assetCountTrigger = StreamProvider.autoDispose.family<int, String>((
  ref,
  projectId,
) {
  return ref.watch(assetDaoProvider).watchCountByProject(projectId);
});

final _promptCountTrigger = StreamProvider.autoDispose.family<int, String>((
  ref,
  projectId,
) {
  return ref.watch(promptDaoProvider).watchCountByProject(projectId);
});

final _taskCountTrigger = StreamProvider.autoDispose.family<int, String>((
  ref,
  projectId,
) {
  return ref.watch(aiTaskDaoProvider).watchCountByProject(projectId);
});

final projectStatsProvider = FutureProvider.autoDispose
    .family<ProjectStats, String>((ref, projectId) async {
      final assetDao = ref.watch(assetDaoProvider);
      final aiTaskDao = ref.watch(aiTaskDaoProvider);

      final counts = await Future.wait([
        ref.watch(_assetCountTrigger(projectId).future),
        ref.watch(_promptCountTrigger(projectId).future),
        ref.watch(_taskCountTrigger(projectId).future),
        assetDao.countByProjectAndType(projectId, 'image'),
        assetDao.countByProjectAndType(projectId, 'video'),
        aiTaskDao.sumTokenUsageByProject(projectId),
      ]);

      return ProjectStats(
        totalAssets: counts[0],
        imageCount: counts[3],
        videoCount: counts[4],
        promptCount: counts[1],
        aiTaskCount: counts[2],
        totalTokenUsage: counts[5],
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
  static final _log = Logger(printer: PrettyPrinter(methodCount: 0));

  Future<String> create({
    required String name,
    String? description,
    String? coverImagePath,
  }) async {
    final id = _uuid.v4();
    final now = epochNowMs();
    await _ref
        .read(projectDaoProvider)
        .insertProject(
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
    if (existing == null) {
      throw StateError('Project $id not found');
    }

    final now = epochNowMs();
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

    final project = await projectDao.getProjectById(id);
    final assets = await assetDao.getByProject(id);
    final assetIds = assets.map((a) => a.id).toList();

    await db.transaction(() async {
      await aiTaskDao.deleteByProject(id);
      await promptDao.deleteByProject(id);
      if (assetIds.isNotEmpty) {
        await assetDao.batchDelete(assetIds);
      }
      await projectDao.deleteProject(id);
    });

    for (final asset in assets) {
      try {
        if (asset.sourceType != 'local_import') {
          await storage.deleteAssetFile(asset.filePath);
        }
        if (asset.thumbnailPath != null) {
          await storage.deleteAssetFile(asset.thumbnailPath!);
        }
      } catch (e) {
        _log.w('Failed to delete asset file: ${asset.filePath}', error: e);
      }
    }

    final coverPath = project?.coverImagePath;
    if (coverPath != null) {
      try {
        await storage.deleteAssetFile(coverPath);
      } catch (e) {
        _log.w('Failed to delete cover: $coverPath', error: e);
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
