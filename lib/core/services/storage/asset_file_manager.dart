import 'dart:convert';
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

  /// Decodes a base64-encoded image and saves it as a project asset.
  ///
  /// Automatically strips a `data:...;base64,` prefix if present.
  Future<Asset> saveFromBase64({
    required String base64Data,
    required String projectId,
    required String name,
    String extension = '.png',
  }) async {
    var raw = base64Data;
    final commaIdx = raw.indexOf(',');
    if (commaIdx != -1 && commaIdx < 100) {
      raw = raw.substring(commaIdx + 1);
    }

    final dir = await _storage.getAssetDirectory(projectId);
    final fileName = '${_uuid.v4()}$extension';
    final destPath = p.join(dir.path, fileName);

    final List<int> bytes;
    try {
      bytes = base64Decode(raw);
    } catch (e) {
      throw FormatException('Invalid base64 data: $e');
    }
    final file = File(destPath);
    await file.writeAsBytes(bytes);

    final thumbPath = await _storage.generateThumbnail(destPath);
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _uuid.v4();

    final companion = AssetsCompanion.insert(
      id: id,
      projectId: Value(projectId),
      name: name,
      type: 'image',
      filePath: destPath,
      thumbnailPath: Value(thumbPath),
      sourceType: 'ai_generated',
      fileSize: Value(bytes.length),
      createdAt: now,
      updatedAt: now,
    );

    await _assetDao.insertAsset(companion);
    final asset = await _assetDao.getAssetById(id);
    _log.d('Saved base64 image: $name → $destPath');
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

  /// Imports a media asset sent from the browser extension.
  ///
  /// Accepts either [mediaUrl] (downloaded via HTTP) or [mediaBase64]
  /// (decoded in-memory). Source metadata (pageUrl, pageTitle) is persisted
  /// in the asset's [metadata] JSON field.
  Future<Asset> importFromExtension({
    String? mediaUrl,
    String? mediaBase64,
    required String mediaType,
    required String fileName,
    String? projectId,
    String? name,
    String? pageUrl,
    String? pageTitle,
  }) async {
    final assetName = name ?? p.basenameWithoutExtension(fileName);
    final ext = p.extension(fileName).isNotEmpty
        ? p.extension(fileName)
        : (mediaType == 'image' ? '.png' : '.mp4');

    // Resolve a storage directory – use the global "unsorted" dir when no
    // project is specified.
    final dir = projectId != null
        ? await _storage.getAssetDirectory(projectId)
        : await _storage.getAssetDirectory('_unsorted');
    final destName = '${_uuid.v4()}$ext';
    final destPath = p.join(dir.path, destName);

    int fileSize;

    if (mediaUrl != null && mediaUrl.isNotEmpty) {
      await _dio.download(mediaUrl, destPath);
      final stat = await File(destPath).stat();
      fileSize = stat.size;
    } else if (mediaBase64 != null && mediaBase64.isNotEmpty) {
      var raw = mediaBase64;
      final commaIdx = raw.indexOf(',');
      if (commaIdx != -1 && commaIdx < 100) {
        raw = raw.substring(commaIdx + 1);
      }
      final bytes = base64Decode(raw);
      await File(destPath).writeAsBytes(bytes);
      fileSize = bytes.length;
    } else {
      throw ArgumentError('Either mediaUrl or mediaBase64 must be provided');
    }

    String? thumbPath;
    if (mediaType == 'image') {
      thumbPath = await _storage.generateThumbnail(destPath);
    }

    final metadataMap = <String, dynamic>{};
    if (pageUrl != null) metadataMap['pageUrl'] = pageUrl;
    if (pageTitle != null) metadataMap['pageTitle'] = pageTitle;

    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    final companion = AssetsCompanion.insert(
      id: id,
      projectId: Value(projectId),
      name: assetName,
      type: mediaType,
      filePath: destPath,
      thumbnailPath: Value(thumbPath),
      originalUrl: Value(mediaUrl),
      sourceType: 'browser_extension',
      fileSize: Value(fileSize),
      metadata:
          Value(metadataMap.isNotEmpty ? jsonEncode(metadataMap) : null),
      createdAt: now,
      updatedAt: now,
    );

    await _assetDao.insertAsset(companion);
    final asset = await _assetDao.getAssetById(id);
    _log.d('Imported from extension: $assetName');
    return asset!;
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
