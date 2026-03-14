import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../database/app_database.dart';
import 'local_storage_service.dart';

class AssetFileManager {
  final AssetDao _assetDao;
  final LocalStorageService _storage;
  final Dio _dio;

  static final _log = Logger(printer: PrettyPrinter(methodCount: 0));
  static const _uuid = Uuid();

  /// Max single-file download: 500 MB.
  static const _maxDownloadBytes = 500 * 1024 * 1024;

  AssetFileManager({
    required AssetDao assetDao,
    required LocalStorageService storage,
    Dio? dio,
  })  : _assetDao = assetDao,
        _storage = storage,
        _dio = dio ?? Dio();

  /// Validates that [url] uses http/https and does not target private networks.
  static void _validateDownloadUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw ArgumentError('Only http/https URLs are allowed, got: $url');
    }

    final host = uri.host.toLowerCase();
    if (host.isEmpty || host == 'localhost') {
      throw ArgumentError('Download from localhost is not allowed');
    }

    final ip = InternetAddress.tryParse(host);
    if (ip != null) {
      bool blocked = false;
      if (ip.type == InternetAddressType.IPv4) {
        final b = ip.rawAddress;
        blocked = b[0] == 127 || // 127.0.0.0/8
            b[0] == 10 || // 10.0.0.0/8
            (b[0] == 172 && b[1] >= 16 && b[1] <= 31) || // 172.16.0.0/12
            (b[0] == 192 && b[1] == 168) || // 192.168.0.0/16
            (b[0] == 169 && b[1] == 254) || // 169.254.0.0/16
            b.every((v) => v == 0); // 0.0.0.0
      } else if (ip.type == InternetAddressType.IPv6) {
        final b = ip.rawAddress;
        final isLoopback = b.last == 1 &&
            b.sublist(0, b.length - 1).every((v) => v == 0); // ::1
        final isLinkLocal = b[0] == 0xfe && (b[1] & 0xc0) == 0x80; // fe80::/10
        final isUla = (b[0] & 0xfe) == 0xfc; // fc00::/7
        final isAllZeros = b.every((v) => v == 0); // ::
        blocked = isLoopback || isLinkLocal || isUla || isAllZeros;
      }
      if (blocked) {
        throw ArgumentError('Download from private/reserved IP is not allowed');
      }
    }
  }

  /// Wraps [Dio.download] with a receive timeout and a size cap.
  /// Issues a HEAD request first to reject oversized files early, then
  /// falls back to progress-based checking during the actual download.
  /// Cleans up the partial file on failure to avoid storage leaks.
  Future<void> _safeDownload(String url, String destPath) async {
    _validateDownloadUrl(url);

    try {
      final headResp = await _dio.head<void>(
        url,
        options: Options(receiveTimeout: const Duration(seconds: 10)),
      );
      final cl = int.tryParse(
        headResp.headers.value('content-length') ?? '',
      );
      if (cl != null && cl > _maxDownloadBytes) {
        throw ArgumentError(
          'File too large: $cl bytes (max $_maxDownloadBytes)',
        );
      }
    } on ArgumentError {
      rethrow;
    } on DioException catch (e) {
      _log.d('HEAD pre-check skipped for $url: $e');
    }

    try {
      await _dio.download(
        url,
        destPath,
        options: Options(receiveTimeout: const Duration(minutes: 10)),
        onReceiveProgress: (received, total) {
          if (received > _maxDownloadBytes) {
            throw DioException(
              requestOptions: RequestOptions(path: url),
              message:
                  'Download exceeded size limit of $_maxDownloadBytes bytes',
            );
          }
        },
      );
    } catch (e) {
      final partial = File(destPath);
      if (await partial.exists()) {
        await partial.delete();
      }
      rethrow;
    }
  }

  /// Imports a local file by referencing its original path (no copy)
  /// and creates a database record.
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

    final stat = await source.stat();

    String? thumbPath;
    if (assetType == 'image') {
      thumbPath = await _storage.generateThumbnail(filePath);
    } else if (assetType == 'video') {
      thumbPath = await _storage.generateVideoThumbnail(filePath);
    }

    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    final companion = AssetsCompanion.insert(
      id: id,
      projectId: Value(projectId),
      name: name,
      type: assetType,
      filePath: filePath,
      thumbnailPath: Value(thumbPath),
      sourceType: 'local_import',
      fileSize: Value(stat.size),
      createdAt: now,
      updatedAt: now,
    );

    await _assetDao.insertAsset(companion);
    final asset = await _assetDao.getAssetById(id);
    _log.d('Imported local file: $name → $filePath');
    return asset ?? (throw StateError('Asset not found after insert: $id'));
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

    await _safeDownload(url, destPath);

    final file = File(destPath);
    final stat = await file.stat();

    String? thumbPath;
    if (assetType == 'image') {
      thumbPath = await _storage.generateThumbnail(destPath);
    } else if (assetType == 'video') {
      thumbPath = await _storage.generateVideoThumbnail(destPath);
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
    return asset ?? (throw StateError('Asset not found after insert: $id'));
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
    final estimatedBytes = (raw.length * 3) ~/ 4;
    if (estimatedBytes > _maxDownloadBytes) {
      throw ArgumentError(
        'Base64 data too large: ~$estimatedBytes bytes '
        '(max $_maxDownloadBytes)',
      );
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
    return asset ?? (throw StateError('Asset not found after insert: $id'));
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
      await _safeDownload(mediaUrl, destPath);
      final stat = await File(destPath).stat();
      fileSize = stat.size;
    } else if (mediaBase64 != null && mediaBase64.isNotEmpty) {
      var raw = mediaBase64;
      final commaIdx = raw.indexOf(',');
      if (commaIdx != -1 && commaIdx < 100) {
        raw = raw.substring(commaIdx + 1);
      }
      final estimatedBytes = (raw.length * 3) ~/ 4;
      if (estimatedBytes > _maxDownloadBytes) {
        throw ArgumentError(
          'Base64 data too large: ~$estimatedBytes bytes '
          '(max $_maxDownloadBytes)',
        );
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
    } else if (mediaType == 'video') {
      thumbPath = await _storage.generateVideoThumbnail(destPath);
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
    return asset ?? (throw StateError('Asset not found after insert: $id'));
  }

  /// Deletes an asset's database record and associated files.
  /// For local imports, only the thumbnail is removed (the original file
  /// belongs to the user). For other source types both the cached file and
  /// thumbnail are deleted.
  Future<void> deleteAsset(String assetId) async {
    final asset = await _assetDao.getAssetById(assetId);
    if (asset == null) return;

    if (asset.sourceType != 'local_import') {
      await _storage.deleteAssetFile(asset.filePath);
    }
    if (asset.thumbnailPath != null) {
      await _storage.deleteAssetFile(asset.thumbnailPath!);
    }
    await _assetDao.deleteAsset(assetId);
    _log.d('Deleted asset: ${asset.name}');
  }
}
