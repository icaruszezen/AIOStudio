import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../database/app_database.dart';
import '../../database/daos/asset_dao.dart';
import 'local_storage_service.dart';

class AssetFileManager {
  final AssetDao _assetDao;
  final LocalStorageService _storage;
  final Dio _dio;

  static final _log = Logger(printer: PrettyPrinter(methodCount: 0));
  static const _uuid = Uuid();

  AssetFileManager({
    required AssetDao assetDao,
    required LocalStorageService storage,
    Dio? dio,
  })  : _assetDao = assetDao,
        _storage = storage,
        _dio = dio ?? Dio();

  /// Imports a local file: copies it into the app's asset directory and
  /// creates a database record.
  Future<Asset> importLocalFile({
    required String filePath,
    required String projectId,
    required String name,
    required String assetType,
  }) async {
    final source = File(filePath);
    if (!await source.exists()) {
      throw FileSystemException('Source file not found', filePath);
    }

    final destPath = await _storage.saveFile(source, projectId);
    final stat = await source.stat();

    String? thumbPath;
    if (assetType == 'image') {
      thumbPath = await _storage.generateThumbnail(destPath);
    }

    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    final companion = AssetsCompanion.insert(
      id: id,
      projectId: Value(projectId),
      name: name,
      type: assetType,
      filePath: destPath,
      thumbnailPath: Value(thumbPath),
      sourceType: 'local_import',
      fileSize: Value(stat.size),
      createdAt: now,
      updatedAt: now,
    );

    await _assetDao.insertAsset(companion);
    final asset = await _assetDao.getAssetById(id);
    _log.d('Imported local file: $name → $destPath');
    return asset!;
  }

  /// Downloads a file from [url] and saves it as a project asset.
  Future<Asset> downloadFromUrl({
    required String url,
    required String projectId,
    required String name,
    required String assetType,
  }) async {
    final dir = await _storage.getAssetDirectory(projectId);
    final ext = p.extension(Uri.parse(url).path);
    final fileName = '${_uuid.v4()}$ext';
    final destPath = p.join(dir.path, fileName);

    await _dio.download(url, destPath);

    final file = File(destPath);
    final stat = await file.stat();

    String? thumbPath;
    if (assetType == 'image') {
      thumbPath = await _storage.generateThumbnail(destPath);
    }

    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    final companion = AssetsCompanion.insert(
      id: id,
      projectId: Value(projectId),
      name: name,
      type: assetType,
      filePath: destPath,
      thumbnailPath: Value(thumbPath),
      originalUrl: Value(url),
      sourceType: 'browser_extension',
      fileSize: Value(stat.size),
      createdAt: now,
      updatedAt: now,
    );

    await _assetDao.insertAsset(companion);
    final asset = await _assetDao.getAssetById(id);
    _log.d('Downloaded file: $name from $url');
    return asset!;
  }

  /// Batch-imports multiple local files.
  Future<List<Asset>> batchImport({
    required List<String> filePaths,
    required String projectId,
    required String assetType,
  }) async {
    final results = <Asset>[];
    for (final path in filePaths) {
      final name = p.basenameWithoutExtension(path);
      final asset = await importLocalFile(
        filePath: path,
        projectId: projectId,
        name: name,
        assetType: assetType,
      );
      results.add(asset);
    }
    return results;
  }

  /// Deletes an asset's file and its database record.
  Future<void> deleteAsset(String assetId) async {
    final asset = await _assetDao.getAssetById(assetId);
    if (asset == null) return;

    await _storage.deleteAssetFile(asset.filePath);
    if (asset.thumbnailPath != null) {
      await _storage.deleteAssetFile(asset.thumbnailPath!);
    }
    await _assetDao.deleteAsset(assetId);
    _log.d('Deleted asset: ${asset.name}');
  }
}
