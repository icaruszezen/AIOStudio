@TestOn('vm')
library;

import 'package:aio_studio/core/database/app_database.dart';
import 'package:aio_studio/core/providers/database_provider.dart';
import 'package:aio_studio/core/services/storage/asset_file_manager.dart';
import 'package:aio_studio/core/services/storage/local_storage_service.dart';
import 'package:aio_studio/features/assets/providers/assets_provider.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalStorageService extends Mock implements LocalStorageService {}

class MockAssetFileManager extends Mock implements AssetFileManager {}

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late MockLocalStorageService mockStorage;
  late MockAssetFileManager mockFileManager;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    mockStorage = MockLocalStorageService();
    mockFileManager = MockAssetFileManager();

    when(() => mockStorage.deleteAssetFile(any())).thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        localStorageServiceProvider.overrideWithValue(mockStorage),
        assetFileManagerProvider.overrideWithValue(mockFileManager),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
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

  Future<String> seedAsset(String projectId, {String name = 'test.png', String type = 'image'}) async {
    final ts = now();
    final id = 'asset-${name.hashCode}';
    await db.assetDao.insertAsset(AssetsCompanion(
      id: Value(id),
      projectId: Value(projectId),
      name: Value(name),
      type: Value(type),
      filePath: Value('/path/$name'),
      sourceType: const Value('local_import'),
      createdAt: Value(ts),
      updatedAt: Value(ts),
    ));
    return id;
  }

  group('AssetActions.inferAssetType', () {
    test('identifies image extensions', () {
      expect(AssetActions.inferAssetType('photo.jpg'), 'image');
      expect(AssetActions.inferAssetType('icon.PNG'), 'image');
      expect(AssetActions.inferAssetType('anim.gif'), 'image');
      expect(AssetActions.inferAssetType('logo.webp'), 'image');
      expect(AssetActions.inferAssetType('icon.svg'), 'image');
    });

    test('identifies video extensions', () {
      expect(AssetActions.inferAssetType('clip.mp4'), 'video');
      expect(AssetActions.inferAssetType('movie.mkv'), 'video');
      expect(AssetActions.inferAssetType('rec.webm'), 'video');
    });

    test('identifies audio extensions', () {
      expect(AssetActions.inferAssetType('song.mp3'), 'audio');
      expect(AssetActions.inferAssetType('track.wav'), 'audio');
      expect(AssetActions.inferAssetType('voice.ogg'), 'audio');
    });

    test('identifies text extensions', () {
      expect(AssetActions.inferAssetType('readme.md'), 'text');
      expect(AssetActions.inferAssetType('data.json'), 'text');
      expect(AssetActions.inferAssetType('main.dart'), 'text');
      expect(AssetActions.inferAssetType('config.yaml'), 'text');
    });

    test('returns other for unknown extensions', () {
      expect(AssetActions.inferAssetType('archive.zip'), 'other');
      expect(AssetActions.inferAssetType('file.exe'), 'other');
      expect(AssetActions.inferAssetType('noext'), 'other');
    });
  });

  group('AssetActions CRUD', () {
    test('toggleFavorite flips the favorite flag', () async {
      await seedProject('proj-1');
      final assetId = await seedAsset('proj-1');
      final actions = container.read(assetActionsProvider);

      var asset = await db.assetDao.getAssetById(assetId);
      expect(asset!.isFavorite, isFalse);

      await actions.toggleFavorite(assetId);
      asset = await db.assetDao.getAssetById(assetId);
      expect(asset!.isFavorite, isTrue);

      await actions.toggleFavorite(assetId);
      asset = await db.assetDao.getAssetById(assetId);
      expect(asset!.isFavorite, isFalse);
    });

    test('updateAsset modifies name', () async {
      await seedProject('proj-1');
      final assetId = await seedAsset('proj-1', name: 'original.png');
      final actions = container.read(assetActionsProvider);

      await actions.updateAsset(id: assetId, name: 'renamed.png');

      final asset = await db.assetDao.getAssetById(assetId);
      expect(asset!.name, 'renamed.png');
    });

    test('moveToProject changes asset projectId', () async {
      await seedProject('proj-1');
      await seedProject('proj-2');
      final assetId = await seedAsset('proj-1');
      final actions = container.read(assetActionsProvider);

      await actions.moveToProject(assetId, 'proj-2');

      final asset = await db.assetDao.getAssetById(assetId);
      expect(asset!.projectId, 'proj-2');
    });

    test('deleteAsset delegates to AssetFileManager', () async {
      when(() => mockFileManager.deleteAsset(any()))
          .thenAnswer((_) async {});

      final actions = container.read(assetActionsProvider);
      await actions.deleteAsset('some-id');

      verify(() => mockFileManager.deleteAsset('some-id')).called(1);
    });

    test('deleteAssets removes records and cleans up files', () async {
      await seedProject('proj-1');
      final id1 = await seedAsset('proj-1', name: 'file1.png');
      final id2 = await seedAsset('proj-1', name: 'file2.png');
      final actions = container.read(assetActionsProvider);

      await actions.deleteAssets([id1, id2]);

      expect(await db.assetDao.getAssetById(id1), isNull);
      expect(await db.assetDao.getAssetById(id2), isNull);
    });

    test('batchToggleFavorite sets favorite on multiple assets', () async {
      await seedProject('proj-1');
      final id1 = await seedAsset('proj-1', name: 'a.png');
      final id2 = await seedAsset('proj-1', name: 'b.png');
      final actions = container.read(assetActionsProvider);

      await actions.batchToggleFavorite([id1, id2], favorite: true);

      final a1 = await db.assetDao.getAssetById(id1);
      final a2 = await db.assetDao.getAssetById(id2);
      expect(a1!.isFavorite, isTrue);
      expect(a2!.isFavorite, isTrue);
    });

    test('getAssetCount returns correct count', () async {
      await seedProject('proj-1');
      await seedAsset('proj-1', name: 'one.png');
      await seedAsset('proj-1', name: 'two.png');
      final actions = container.read(assetActionsProvider);

      final count = await actions.getAssetCount();
      expect(count, 2);
    });
  });
}
