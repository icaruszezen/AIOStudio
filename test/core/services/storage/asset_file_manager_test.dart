@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:aio_studio/core/database/app_database.dart';
import 'package:aio_studio/core/services/storage/asset_file_manager.dart';
import 'package:aio_studio/core/services/storage/local_storage_service.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

class MockLocalStorageService extends Mock implements LocalStorageService {}

void main() {
  late AppDatabase db;
  late AssetDao assetDao;
  late MockLocalStorageService mockStorage;
  late AssetFileManager manager;
  late Directory tempDir;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    assetDao = db.assetDao;
    mockStorage = MockLocalStorageService();
    tempDir = await Directory.systemTemp.createTemp('aio_afm_test_');
    manager = AssetFileManager(
      assetDao: assetDao,
      storage: mockStorage,
    );
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  int now() => DateTime.now().millisecondsSinceEpoch;

  Future<void> seedProject(String id) async {
    final ts = now();
    await db.projectDao.insertProject(ProjectsCompanion(
      id: Value(id),
      name: Value('Project $id'),
      createdAt: Value(ts),
      updatedAt: Value(ts),
    ));
  }

  group('importLocalFile', () {
    test('creates asset record for existing file', () async {
      await seedProject('proj-1');
      final sourceFile = File(p.join(tempDir.path, 'test.txt'));
      await sourceFile.writeAsString('content');

      when(() => mockStorage.generateThumbnail(any()))
          .thenAnswer((_) async => null);
      when(() => mockStorage.generateVideoThumbnail(any()))
          .thenAnswer((_) async => null);

      final asset = await manager.importLocalFile(
        filePath: sourceFile.path,
        projectId: 'proj-1',
        name: 'test file',
        assetType: 'text',
      );

      expect(asset.name, 'test file');
      expect(asset.type, 'text');
      expect(asset.filePath, sourceFile.path);
      expect(asset.sourceType, 'local_import');
      expect(asset.projectId, 'proj-1');
    });

    test('generates thumbnail for image type', () async {
      await seedProject('proj-1');
      final sourceFile = File(p.join(tempDir.path, 'photo.png'));
      await sourceFile.writeAsBytes([0x89, 0x50, 0x4E, 0x47]);

      when(() => mockStorage.generateThumbnail(any()))
          .thenAnswer((_) async => '/thumbnails/thumb.jpg');

      final asset = await manager.importLocalFile(
        filePath: sourceFile.path,
        projectId: 'proj-1',
        name: 'photo',
        assetType: 'image',
      );

      verify(() => mockStorage.generateThumbnail(sourceFile.path)).called(1);
      expect(asset.thumbnailPath, '/thumbnails/thumb.jpg');
    });

    test('generates video thumbnail for video type', () async {
      await seedProject('proj-1');
      final sourceFile = File(p.join(tempDir.path, 'clip.mp4'));
      await sourceFile.writeAsBytes([0x00, 0x01, 0x02]);

      when(() => mockStorage.generateVideoThumbnail(any()))
          .thenAnswer((_) async => '/thumbnails/vthumb.jpg');

      final asset = await manager.importLocalFile(
        filePath: sourceFile.path,
        projectId: 'proj-1',
        name: 'clip',
        assetType: 'video',
      );

      verify(() => mockStorage.generateVideoThumbnail(sourceFile.path))
          .called(1);
      expect(asset.thumbnailPath, '/thumbnails/vthumb.jpg');
    });

    test('throws when source file does not exist', () {
      expect(
        () => manager.importLocalFile(
          filePath: '/nonexistent/file.txt',
          projectId: 'proj-1',
          name: 'missing',
          assetType: 'text',
        ),
        throwsA(isA<FileSystemException>()),
      );
    });
  });

  group('saveFromBase64', () {
    test('saves decoded base64 data as asset', () async {
      await seedProject('proj-1');
      final testBytes = utf8.encode('hello world');
      final b64 = base64Encode(testBytes);
      final assetDir = Directory(p.join(tempDir.path, 'assets', 'proj-1'));
      await assetDir.create(recursive: true);

      when(() => mockStorage.getAssetDirectory(any()))
          .thenAnswer((_) async => assetDir);
      when(() => mockStorage.generateThumbnail(any()))
          .thenAnswer((_) async => null);

      final asset = await manager.saveFromBase64(
        base64Data: b64,
        projectId: 'proj-1',
        name: 'generated_image',
      );

      expect(asset.name, 'generated_image');
      expect(asset.type, 'image');
      expect(asset.sourceType, 'ai_generated');
    });

    test('strips data URI prefix', () async {
      await seedProject('proj-1');
      final testBytes = utf8.encode('test data');
      final b64 = 'data:image/png;base64,${base64Encode(testBytes)}';
      final assetDir = Directory(p.join(tempDir.path, 'assets', 'proj-1'));
      await assetDir.create(recursive: true);

      when(() => mockStorage.getAssetDirectory(any()))
          .thenAnswer((_) async => assetDir);
      when(() => mockStorage.generateThumbnail(any()))
          .thenAnswer((_) async => null);

      final asset = await manager.saveFromBase64(
        base64Data: b64,
        projectId: 'proj-1',
        name: 'from_uri',
      );

      expect(asset, isNotNull);
    });

    test('throws FormatException for invalid base64', () async {
      final assetDir = Directory(p.join(tempDir.path, 'assets', 'proj-1'));
      await assetDir.create(recursive: true);

      when(() => mockStorage.getAssetDirectory(any()))
          .thenAnswer((_) async => assetDir);

      expect(
        () => manager.saveFromBase64(
          base64Data: '!!!invalid!!!',
          projectId: 'proj-1',
          name: 'bad_data',
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('deleteAsset', () {
    test('deletes non-local-import asset file and thumbnail', () async {
      await seedProject('proj-1');
      final ts = now();
      await assetDao.insertAsset(AssetsCompanion(
        id: const Value('asset-1'),
        projectId: const Value('proj-1'),
        name: const Value('downloaded.png'),
        type: const Value('image'),
        filePath: const Value('/cache/downloaded.png'),
        thumbnailPath: const Value('/cache/thumb.jpg'),
        sourceType: const Value('browser_extension'),
        createdAt: Value(ts),
        updatedAt: Value(ts),
      ));

      when(() => mockStorage.deleteAssetFile(any()))
          .thenAnswer((_) async {});

      await manager.deleteAsset('asset-1');

      verify(() => mockStorage.deleteAssetFile('/cache/downloaded.png'))
          .called(1);
      verify(() => mockStorage.deleteAssetFile('/cache/thumb.jpg')).called(1);

      final deleted = await assetDao.getAssetById('asset-1');
      expect(deleted, isNull);
    });

    test('skips file deletion for local_import source type', () async {
      await seedProject('proj-1');
      final ts = now();
      await assetDao.insertAsset(AssetsCompanion(
        id: const Value('asset-2'),
        projectId: const Value('proj-1'),
        name: const Value('local.png'),
        type: const Value('image'),
        filePath: const Value('/user/photos/local.png'),
        thumbnailPath: const Value('/cache/thumb.jpg'),
        sourceType: const Value('local_import'),
        createdAt: Value(ts),
        updatedAt: Value(ts),
      ));

      when(() => mockStorage.deleteAssetFile(any()))
          .thenAnswer((_) async {});

      await manager.deleteAsset('asset-2');

      verifyNever(() => mockStorage.deleteAssetFile('/user/photos/local.png'));
      verify(() => mockStorage.deleteAssetFile('/cache/thumb.jpg')).called(1);
    });

    test('does nothing for nonexistent asset', () async {
      await manager.deleteAsset('nonexistent-id');
      verifyNever(() => mockStorage.deleteAssetFile(any()));
    });
  });

  group('importFromExtension', () {
    test('throws when neither mediaUrl nor mediaBase64 provided', () async {
      final assetDir = Directory(p.join(tempDir.path, 'unsorted'));
      await assetDir.create(recursive: true);
      when(() => mockStorage.getAssetDirectory(any()))
          .thenAnswer((_) async => assetDir);

      expect(
        () => manager.importFromExtension(
          mediaType: 'image',
          fileName: 'file.png',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects non-http URL schemes', () async {
      final assetDir = Directory(p.join(tempDir.path, 'unsorted'));
      await assetDir.create(recursive: true);
      when(() => mockStorage.getAssetDirectory(any()))
          .thenAnswer((_) async => assetDir);

      expect(
        () => manager.importFromExtension(
          mediaUrl: 'ftp://example.com/file.png',
          mediaType: 'image',
          fileName: 'file.png',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects localhost URLs', () async {
      final assetDir = Directory(p.join(tempDir.path, 'unsorted'));
      await assetDir.create(recursive: true);
      when(() => mockStorage.getAssetDirectory(any()))
          .thenAnswer((_) async => assetDir);

      expect(
        () => manager.importFromExtension(
          mediaUrl: 'http://localhost/file.png',
          mediaType: 'image',
          fileName: 'file.png',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects private IP addresses', () async {
      final assetDir = Directory(p.join(tempDir.path, 'unsorted'));
      await assetDir.create(recursive: true);
      when(() => mockStorage.getAssetDirectory(any()))
          .thenAnswer((_) async => assetDir);

      expect(
        () => manager.importFromExtension(
          mediaUrl: 'http://192.168.1.1/file.png',
          mediaType: 'image',
          fileName: 'file.png',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
