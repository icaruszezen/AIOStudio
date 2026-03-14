import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';

// ---------------------------------------------------------------------------
// Stream providers
// ---------------------------------------------------------------------------

final allAssetsProvider = StreamProvider<List<Asset>>((ref) {
  return ref.watch(assetDaoProvider).watchAssets();
});

final assetsByProjectProvider =
    StreamProvider.family<List<Asset>, String>((ref, projectId) {
  return ref.watch(assetDaoProvider).watchAssets(projectId: projectId);
});

final favoriteAssetsProvider = StreamProvider<List<Asset>>((ref) {
  return ref.watch(assetDaoProvider).watchFavorites();
});

final assetDetailProvider =
    FutureProvider.family<Asset?, String>((ref, id) {
  return ref.watch(assetDaoProvider).getAssetById(id);
});

// ---------------------------------------------------------------------------
// Asset actions
// ---------------------------------------------------------------------------

final assetActionsProvider = Provider<AssetActions>((ref) {
  return AssetActions(ref);
});

class AssetActions {
  AssetActions(this._ref);

  final Ref _ref;

  static const _imageExtensions = {
    '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.svg', '.ico', '.tiff',
  };
  static const _videoExtensions = {
    '.mp4', '.avi', '.mov', '.mkv', '.wmv', '.flv', '.webm', '.m4v',
  };
  static const _audioExtensions = {
    '.mp3', '.wav', '.flac', '.aac', '.ogg', '.wma', '.m4a',
  };
  static const _textExtensions = {
    '.txt', '.md', '.json', '.xml', '.csv', '.html', '.css', '.js',
    '.dart', '.py', '.yaml', '.yml', '.toml', '.ini', '.log',
  };

  static String inferAssetType(String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    if (_imageExtensions.contains(ext)) return 'image';
    if (_videoExtensions.contains(ext)) return 'video';
    if (_audioExtensions.contains(ext)) return 'audio';
    if (_textExtensions.contains(ext)) return 'text';
    return 'other';
  }

  Future<List<Asset>> importLocalFiles(
    List<String> filePaths, {
    String? projectId,
  }) async {
    final manager = _ref.read(assetFileManagerProvider);
    final results = <Asset>[];
    for (final filePath in filePaths) {
      final name = p.basenameWithoutExtension(filePath);
      final type = inferAssetType(filePath);
      final asset = await manager.importLocalFile(
        filePath: filePath,
        projectId: projectId ?? '',
        name: name,
        assetType: type,
      );
      results.add(asset);
    }
    return results;
  }

  Future<Asset> importFromUrl(String url, {String? projectId}) async {
    final manager = _ref.read(assetFileManagerProvider);
    final uri = Uri.parse(url);
    final name = p.basenameWithoutExtension(uri.path);
    final type = inferAssetType(uri.path);
    return manager.downloadFromUrl(
      url: url,
      projectId: projectId ?? '',
      name: name.isEmpty ? 'download' : name,
      assetType: type,
    );
  }

  Future<void> deleteAsset(String id) async {
    await _ref.read(assetFileManagerProvider).deleteAsset(id);
  }

  Future<void> deleteAssets(List<String> ids) async {
    final dao = _ref.read(assetDaoProvider);
    final storage = _ref.read(localStorageServiceProvider);

    final assets = await Future.wait(ids.map(dao.getAssetById));
    for (final asset in assets) {
      if (asset == null) continue;
      if (asset.sourceType != 'local_import') {
        await storage.deleteAssetFile(asset.filePath);
      }
      if (asset.thumbnailPath != null) {
        await storage.deleteAssetFile(asset.thumbnailPath!);
      }
    }

    final db = _ref.read(appDatabaseProvider);
    await db.transaction(() => dao.batchDelete(ids));
  }

  Future<void> toggleFavorite(String id) async {
    final dao = _ref.read(assetDaoProvider);
    final asset = await dao.getAssetById(id);
    if (asset == null) return;
    await dao.toggleFavorite(id, favorite: !asset.isFavorite);
  }

  Future<void> updateAsset({
    required String id,
    String? name,
    String? projectId,
    bool clearProject = false,
  }) async {
    final dao = _ref.read(assetDaoProvider);
    final existing = await dao.getAssetById(id);
    if (existing == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    await dao.updateAsset(
      AssetsCompanion(
        id: Value(existing.id),
        projectId: Value(clearProject ? null : (projectId ?? existing.projectId)),
        name: Value(name ?? existing.name),
        type: Value(existing.type),
        filePath: Value(existing.filePath),
        thumbnailPath: Value(existing.thumbnailPath),
        originalUrl: Value(existing.originalUrl),
        sourceType: Value(existing.sourceType),
        fileSize: Value(existing.fileSize),
        width: Value(existing.width),
        height: Value(existing.height),
        duration: Value(existing.duration),
        metadata: Value(existing.metadata),
        createdAt: Value(existing.createdAt),
        updatedAt: Value(now),
        isFavorite: Value(existing.isFavorite),
      ),
    );
  }

  Future<void> moveToProject(String assetId, String? projectId) =>
      updateAsset(id: assetId, projectId: projectId, clearProject: projectId == null);

  Future<void> batchMoveToProject(List<String> ids, String? projectId) =>
      _ref.read(assetDaoProvider).batchMoveToProject(ids, projectId);

  Future<void> batchToggleFavorite(List<String> ids, {required bool favorite}) =>
      _ref.read(assetDaoProvider).batchToggleFavorite(ids, favorite: favorite);

  Future<int> getAssetCount() =>
      _ref.read(assetDaoProvider).countAllAssets();
}
