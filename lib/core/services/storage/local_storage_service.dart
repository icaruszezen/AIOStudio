import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:logger/logger.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
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
  final String? cacheDirectory;

  LocalStorageService({this.cacheDirectory});

  static final _log = Logger(printer: PrettyPrinter(methodCount: 0));
  static const _uuid = Uuid();

  Future<Directory> get _appDataDir async {
    if (cacheDirectory != null) {
      return Directory(cacheDirectory!);
    }
    final dir = await getApplicationSupportDirectory();
    return Directory(p.join(dir.path, 'aio_data'));
  }

  static Future<String> get defaultCachePath async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, 'aio_data');
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

  /// Extracts a frame from the video at [videoPath] using media_kit and saves
  /// it as a JPEG thumbnail. Seeks to ~10 % of total duration (clamped between
  /// 2 s and 30 s) to skip past intros and capture a representative frame.
  Future<String?> generateVideoThumbnail(String videoPath) async {
    final file = File(videoPath);
    if (!await file.exists()) return null;

    final thumbDir = await getThumbnailDirectory();
    final thumbName = '${_uuid.v4()}_vthumb.jpg';
    final thumbPath = p.join(thumbDir.path, thumbName);

    final player = Player();
    try {
      // VideoController must be attached for Player.screenshot() to work.
      // ignore: unused_local_variable
      final controller = VideoController(player);
      await player.open(Media(videoPath), play: false);

      // Wait until the video duration is known (with timeout).
      final duration = await player.stream.duration
          .firstWhere((d) => d > Duration.zero)
          .timeout(const Duration(seconds: 8));

      final tenPercent = (duration.inMilliseconds * 0.1).round();
      final seekMs = tenPercent.clamp(2000, 30000).clamp(0, duration.inMilliseconds);
      await player.seek(Duration(milliseconds: seekMs));

      // Give the decoder a moment to render the seeked frame.
      await Future<void>.delayed(const Duration(milliseconds: 500));

      final Uint8List? bytes =
          await player.screenshot(format: 'image/jpeg');
      if (bytes == null || bytes.isEmpty) {
        _log.w('Video screenshot returned null for $videoPath');
        return null;
      }

      await File(thumbPath).writeAsBytes(bytes);
      _log.d('Generated video thumbnail: $thumbPath');
      return thumbPath;
    } on TimeoutException {
      _log.w('Timed out waiting for video duration: $videoPath');
      return null;
    } catch (e) {
      _log.w('Video thumbnail generation failed: $e');
      return null;
    } finally {
      await player.dispose();
    }
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

  /// Migrates all cached files from [oldRoot] to [newRoot], preserving
  /// the relative directory structure. Calls [onProgress] after each file.
  /// Deletes the old directory tree when finished.
  Future<void> migrateCache({
    required String oldRoot,
    required String newRoot,
    required void Function(int current, int total) onProgress,
  }) async {
    final oldDir = Directory(oldRoot);
    if (!await oldDir.exists()) return;

    final files = <File>[];
    await for (final entity in oldDir.list(recursive: true)) {
      if (entity is File) files.add(entity);
    }

    if (files.isEmpty) {
      await oldDir.delete(recursive: true);
      return;
    }

    for (var i = 0; i < files.length; i++) {
      final relative = p.relative(files[i].path, from: oldRoot);
      final newPath = p.join(newRoot, relative);
      await Directory(p.dirname(newPath)).create(recursive: true);
      await files[i].copy(newPath);
      onProgress(i + 1, files.length);
    }

    await oldDir.delete(recursive: true);
    _log.i('Migrated ${ files.length} files from $oldRoot to $newRoot');
  }
}
