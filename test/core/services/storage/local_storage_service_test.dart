@TestOn('vm')
library;

import 'dart:io';

import 'package:aio_studio/core/services/storage/local_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late LocalStorageService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('aio_test_');
    service = LocalStorageService(cacheDirectory: tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('StorageStats', () {
    test('totalSizeMB computes correctly', () {
      const stats = StorageStats(totalFiles: 10, totalSizeBytes: 5242880);
      expect(stats.totalSizeMB, 5.0);
    });
  });

  group('DetailedStorageStats', () {
    test('sub-category MB values are correct', () {
      const stats = DetailedStorageStats(
        totalFiles: 3,
        totalSizeBytes: 3145728,
        imagesSizeBytes: 1048576,
        videosSizeBytes: 1048576,
        othersSizeBytes: 1048576,
      );
      expect(stats.imagesSizeMB, 1.0);
      expect(stats.videosSizeMB, 1.0);
      expect(stats.othersSizeMB, 1.0);
    });
  });

  group('getAssetDirectory', () {
    test('creates directory for valid projectId', () async {
      final dir = await service.getAssetDirectory('proj-1');
      expect(await dir.exists(), isTrue);
      expect(dir.path, contains('assets'));
      expect(dir.path, contains('proj-1'));
    });

    test('throws for invalid projectId with path traversal', () {
      expect(
        () => service.getAssetDirectory('../escape'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws for empty projectId', () {
      expect(
        () => service.getAssetDirectory(''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws for projectId with special chars', () {
      expect(
        () => service.getAssetDirectory('test/../../etc'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('getThumbnailDirectory', () {
    test('creates thumbnails directory', () async {
      final dir = await service.getThumbnailDirectory();
      expect(await dir.exists(), isTrue);
      expect(dir.path, contains('thumbnails'));
    });
  });

  group('saveFile', () {
    test('copies file to project asset directory', () async {
      final source = File(p.join(tempDir.path, 'source.txt'));
      await source.writeAsString('test content');

      final savedPath = await service.saveFile(source, 'proj-1');
      expect(File(savedPath).existsSync(), isTrue);
      expect(await File(savedPath).readAsString(), 'test content');
      expect(savedPath, contains('proj-1'));
    });

    test('generates unique filename with original extension', () async {
      final source = File(p.join(tempDir.path, 'photo.png'));
      await source.writeAsBytes([0x89, 0x50, 0x4E, 0x47]);

      final savedPath = await service.saveFile(source, 'proj-2');
      expect(p.extension(savedPath), '.png');
    });
  });

  group('deleteAssetFile', () {
    test('deletes file within data directory', () async {
      final dir = await service.getAssetDirectory('proj-1');
      final file = File(p.join(dir.path, 'test.txt'));
      await file.writeAsString('to delete');

      await service.deleteAssetFile(file.path);
      expect(file.existsSync(), isFalse);
    });

    test('blocks deletion outside data directory', () async {
      final outsideFile = File(p.join(tempDir.parent.path, 'outside.txt'));
      await outsideFile.writeAsString('should not delete');

      await service.deleteAssetFile(outsideFile.path);
      expect(outsideFile.existsSync(), isTrue);

      await outsideFile.delete();
    });

    test('does nothing if file does not exist', () async {
      final dir = await service.getAssetDirectory('proj-1');
      final fakePath = p.join(dir.path, 'nonexistent.txt');
      await service.deleteAssetFile(fakePath);
    });
  });

  group('getStorageStats', () {
    test('returns zero stats for empty directory', () async {
      final stats = await service.getStorageStats();
      expect(stats.totalFiles, 0);
      expect(stats.totalSizeBytes, 0);
    });

    test('counts files and sizes correctly', () async {
      final dir = await service.getAssetDirectory('proj-1');
      await File(p.join(dir.path, 'a.txt')).writeAsString('hello');
      await File(p.join(dir.path, 'b.txt')).writeAsString('world!');

      final stats = await service.getStorageStats();
      expect(stats.totalFiles, 2);
      expect(stats.totalSizeBytes, greaterThan(0));
    });
  });

  group('getDetailedStorageStats', () {
    test('categorizes files by extension', () async {
      final dir = await service.getAssetDirectory('proj-1');
      await File(p.join(dir.path, 'photo.jpg')).writeAsBytes([1, 2, 3]);
      await File(p.join(dir.path, 'clip.mp4')).writeAsBytes([4, 5, 6, 7]);
      await File(p.join(dir.path, 'doc.pdf')).writeAsBytes([8, 9]);

      final stats = await service.getDetailedStorageStats();
      expect(stats.totalFiles, 3);
      expect(stats.imagesSizeBytes, 3);
      expect(stats.videosSizeBytes, 4);
      expect(stats.othersSizeBytes, 2);
      expect(stats.totalSizeBytes, 9);
    });
  });

  group('clearThumbnailCache', () {
    test('removes all thumbnail files and recreates directory', () async {
      final thumbDir = await service.getThumbnailDirectory();
      await File(p.join(thumbDir.path, 'thumb1.jpg')).writeAsBytes([1, 2]);
      await File(p.join(thumbDir.path, 'thumb2.jpg')).writeAsBytes([3, 4]);

      await service.clearThumbnailCache();

      expect(await thumbDir.exists(), isTrue);
      final remaining = thumbDir.listSync();
      expect(remaining, isEmpty);
    });
  });

  group('getStoragePath', () {
    test('returns the cacheDirectory path', () async {
      final path = await service.getStoragePath();
      expect(path, tempDir.path);
    });
  });

  group('migrateCache', () {
    test('moves files preserving directory structure', () async {
      final oldRoot = p.join(tempDir.path, 'old_cache');
      final newRoot = p.join(tempDir.path, 'new_cache');

      await Directory(p.join(oldRoot, 'sub')).create(recursive: true);
      await File(p.join(oldRoot, 'file1.txt')).writeAsString('one');
      await File(p.join(oldRoot, 'sub', 'file2.txt')).writeAsString('two');

      final progress = <String>[];
      await service.migrateCache(
        oldRoot: oldRoot,
        newRoot: newRoot,
        onProgress: (current, total) {
          progress.add('$current/$total');
        },
      );

      expect(File(p.join(newRoot, 'file1.txt')).existsSync(), isTrue);
      expect(File(p.join(newRoot, 'sub', 'file2.txt')).existsSync(), isTrue);
      expect(await File(p.join(newRoot, 'file1.txt')).readAsString(), 'one');
      expect(Directory(oldRoot).existsSync(), isFalse);
      expect(progress, hasLength(2));
    });

    test('does nothing if old directory does not exist', () async {
      await service.migrateCache(
        oldRoot: p.join(tempDir.path, 'nonexistent'),
        newRoot: p.join(tempDir.path, 'target'),
        onProgress: (_, __) {},
      );
    });

    test('deletes empty old directory without errors', () async {
      final oldRoot = p.join(tempDir.path, 'empty_cache');
      await Directory(oldRoot).create();

      await service.migrateCache(
        oldRoot: oldRoot,
        newRoot: p.join(tempDir.path, 'new_cache'),
        onProgress: (_, __) {},
      );

      expect(Directory(oldRoot).existsSync(), isFalse);
    });
  });
}
