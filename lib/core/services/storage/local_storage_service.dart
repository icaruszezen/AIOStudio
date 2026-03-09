import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class StorageStats {
  final int totalFiles;
  final int totalSizeBytes;

  const StorageStats({required this.totalFiles, required this.totalSizeBytes});

  double get totalSizeMB => totalSizeBytes / (1024 * 1024);
}

class DetailedStorageStats extends StorageStats {
  final int imagesSizeBytes;
  final int videosSizeBytes;
  final int othersSizeBytes;

  const DetailedStorageStats({
    required super.totalFiles,
    required super.totalSizeBytes,
    required this.imagesSizeBytes,
    required this.videosSizeBytes,
    required this.othersSizeBytes,
  });

  double get imagesSizeMB => imagesSizeBytes / (1024 * 1024);
  double get videosSizeMB => videosSizeBytes / (1024 * 1024);
  double get othersSizeMB => othersSizeBytes / (1024 * 1024);
}

const _imageExtensions = {
  '.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.tiff', '.svg',
};
const _videoExtensions = {
  '.mp4', '.mov', '.avi', '.mkv', '.webm', '.flv', '.wmv',
};

class LocalStorageService {
  static final _log = Logger(printer: PrettyPrinter(methodCount: 0));
  static const _uuid = Uuid();

  Future<Directory> get _appDataDir async {
    final dir = await getApplicationSupportDirectory();
    return Directory(p.join(dir.path, 'aio_data'));
  }

  Future<Directory> getAssetDirectory(String projectId) async {
    final root = await _appDataDir;
    final dir = Directory(p.join(root.path, 'assets', projectId));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> getThumbnailDirectory() async {
    final root = await _appDataDir;
    final dir = Directory(p.join(root.path, 'thumbnails'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Copies [sourceFile] into the project's asset directory.
  /// Returns the destination file path.
  Future<String> saveFile(File sourceFile, String projectId) async {
    final dir = await getAssetDirectory(projectId);
    final ext = p.extension(sourceFile.path);
    final destName = '${_uuid.v4()}$ext';
    final dest = File(p.join(dir.path, destName));
    await sourceFile.copy(dest.path);
    _log.d('Saved file to ${dest.path}');
    return dest.path;
  }

  static const _thumbWidth = 300;

  /// Decodes the image at [imagePath], resizes it to [_thumbWidth] px wide
  /// (preserving aspect ratio), and saves the result as a JPEG thumbnail.
  /// Falls back to copying the original if decoding fails (e.g. SVG).
  Future<String?> generateThumbnail(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) return null;

    final thumbDir = await getThumbnailDirectory();
    final thumbName = '${_uuid.v4()}_thumb.jpg';
    final thumbPath = p.join(thumbDir.path, thumbName);

    try {
      final Uint8List bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        await file.copy(thumbPath);
        return thumbPath;
      }

      final resized = img.copyResize(decoded, width: _thumbWidth);
      final encoded = img.encodeJpg(resized, quality: 85);
      await File(thumbPath).writeAsBytes(encoded);
    } catch (e) {
      _log.w('Thumbnail generation failed, copying original: $e');
      await file.copy(thumbPath);
    }

    return thumbPath;
  }

  Future<void> deleteAssetFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
      _log.d('Deleted file: $filePath');
    }
  }

  Future<StorageStats> getStorageStats() async {
    final root = await _appDataDir;
    if (!await root.exists()) {
      return const StorageStats(totalFiles: 0, totalSizeBytes: 0);
    }

    var totalFiles = 0;
    var totalSize = 0;
    await for (final entity in root.list(recursive: true)) {
      if (entity is File) {
        totalFiles++;
        totalSize += await entity.length();
      }
    }
    return StorageStats(totalFiles: totalFiles, totalSizeBytes: totalSize);
  }

  Future<DetailedStorageStats> getDetailedStorageStats() async {
    final root = await _appDataDir;
    if (!await root.exists()) {
      return const DetailedStorageStats(
        totalFiles: 0,
        totalSizeBytes: 0,
        imagesSizeBytes: 0,
        videosSizeBytes: 0,
        othersSizeBytes: 0,
      );
    }

    var totalFiles = 0;
    var totalSize = 0;
    var imagesSize = 0;
    var videosSize = 0;
    var othersSize = 0;

    await for (final entity in root.list(recursive: true)) {
      if (entity is File) {
        totalFiles++;
        final size = await entity.length();
        totalSize += size;
        final ext = p.extension(entity.path).toLowerCase();
        if (_imageExtensions.contains(ext)) {
          imagesSize += size;
        } else if (_videoExtensions.contains(ext)) {
          videosSize += size;
        } else {
          othersSize += size;
        }
      }
    }

    return DetailedStorageStats(
      totalFiles: totalFiles,
      totalSizeBytes: totalSize,
      imagesSizeBytes: imagesSize,
      videosSizeBytes: videosSize,
      othersSizeBytes: othersSize,
    );
  }

  Future<void> clearThumbnailCache() async {
    final thumbDir = await getThumbnailDirectory();
    if (await thumbDir.exists()) {
      await thumbDir.delete(recursive: true);
      await thumbDir.create(recursive: true);
      _log.i('Thumbnail cache cleared');
    }
  }

  Future<String> getStoragePath() async {
    final root = await _appDataDir;
    return root.path;
  }
}
