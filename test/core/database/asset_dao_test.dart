@TestOn('vm')
library;

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aio_studio/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  late AssetDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = db.assetDao;
  });

  tearDown(() async {
    await db.close();
  });

  int _now() => DateTime.now().millisecondsSinceEpoch;

  AssetsCompanion _makeAsset(
    String id,
    String name, {
    String type = 'image',
    String? projectId,
    bool isFavorite = false,
  }) {
    final ts = _now();
    return AssetsCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      filePath: Value('/path/$id'),
      sourceType: Value('local'),
      createdAt: Value(ts),
      updatedAt: Value(ts),
      projectId: Value(projectId),
      isFavorite: Value(isFavorite),
    );
  }

  Future<void> _seedProject(String id) async {
    final ts = _now();
    await db.projectDao.insertProject(ProjectsCompanion(
      id: Value(id),
      name: Value('Project $id'),
      createdAt: Value(ts),
      updatedAt: Value(ts),
    ));
  }

  group('AssetDao', () {
    test('insertAsset and getAllAssets', () async {
      await dao.insertAsset(_makeAsset('a1', 'Image One'));
      await dao.insertAsset(_makeAsset('a2', 'Image Two'));

      final all = await dao.getAllAssets();
      expect(all, hasLength(2));
    });

    test('getAssetById returns correct asset', () async {
      await dao.insertAsset(_makeAsset('a1', 'Photo'));

      final found = await dao.getAssetById('a1');
      expect(found, isNotNull);
      expect(found!.name, 'Photo');

      expect(await dao.getAssetById('missing'), isNull);
    });

    test('updateAsset replaces the row', () async {
      await dao.insertAsset(_makeAsset('a1', 'Old'));
      final original = await dao.getAssetById('a1');

      final ok = await dao.updateAsset(AssetsCompanion(
        id: Value('a1'),
        name: Value('New'),
        type: Value(original!.type),
        filePath: Value(original.filePath),
        sourceType: Value(original.sourceType),
        createdAt: Value(original.createdAt),
        updatedAt: Value(_now()),
        isFavorite: Value(original.isFavorite),
      ));
      expect(ok, isTrue);

      final fetched = await dao.getAssetById('a1');
      expect(fetched!.name, 'New');
    });

    test('deleteAsset removes the row', () async {
      await dao.insertAsset(_makeAsset('a1', 'Gone'));
      await dao.deleteAsset('a1');
      expect(await dao.getAllAssets(), isEmpty);
    });

    test('getByProject filters by projectId', () async {
      await _seedProject('proj1');
      await dao.insertAsset(_makeAsset('a1', 'A', projectId: 'proj1'));
      await dao.insertAsset(_makeAsset('a2', 'B'));

      final byProject = await dao.getByProject('proj1');
      expect(byProject, hasLength(1));
      expect(byProject.first.id, 'a1');
    });

    test('filterByType returns matching type', () async {
      await dao.insertAsset(_makeAsset('a1', 'Img', type: 'image'));
      await dao.insertAsset(_makeAsset('a2', 'Vid', type: 'video'));
      await dao.insertAsset(_makeAsset('a3', 'Img2', type: 'image'));

      final images = await dao.filterByType('image');
      expect(images, hasLength(2));

      final videos = await dao.filterByType('video');
      expect(videos, hasLength(1));
    });

    test('toggleFavorite updates the flag', () async {
      await dao.insertAsset(_makeAsset('a1', 'Star'));

      await dao.toggleFavorite('a1', favorite: true);
      var a = await dao.getAssetById('a1');
      expect(a!.isFavorite, isTrue);

      await dao.toggleFavorite('a1', favorite: false);
      a = await dao.getAssetById('a1');
      expect(a!.isFavorite, isFalse);
    });

    test('getPaginated respects limit and offset', () async {
      for (var i = 0; i < 10; i++) {
        await dao.insertAsset(_makeAsset('a$i', 'Asset $i'));
      }

      final page1 = await dao.getPaginated(limit: 3, offset: 0);
      expect(page1, hasLength(3));

      final page2 = await dao.getPaginated(limit: 3, offset: 3);
      expect(page2, hasLength(3));

      final allIds = {...page1.map((a) => a.id), ...page2.map((a) => a.id)};
      expect(allIds, hasLength(6));
    });

    test('countByProject and countByProjectAndType', () async {
      await _seedProject('proj1');
      await dao.insertAsset(_makeAsset('a1', 'I1', type: 'image', projectId: 'proj1'));
      await dao.insertAsset(_makeAsset('a2', 'V1', type: 'video', projectId: 'proj1'));
      await dao.insertAsset(_makeAsset('a3', 'I2', type: 'image', projectId: 'proj1'));

      expect(await dao.countByProject('proj1'), 3);
      expect(await dao.countByProjectAndType('proj1', 'image'), 2);
      expect(await dao.countByProjectAndType('proj1', 'video'), 1);
    });

    test('searchByName finds matching names', () async {
      await dao.insertAsset(_makeAsset('a1', 'sunset_photo'));
      await dao.insertAsset(_makeAsset('a2', 'mountain_photo'));
      await dao.insertAsset(_makeAsset('a3', 'logo_design'));

      final results = await dao.searchByName('photo');
      expect(results, hasLength(2));
    });

    test('batchDelete removes multiple assets', () async {
      await dao.insertAsset(_makeAsset('a1', 'One'));
      await dao.insertAsset(_makeAsset('a2', 'Two'));
      await dao.insertAsset(_makeAsset('a3', 'Three'));

      await dao.batchDelete(['a1', 'a3']);
      final remaining = await dao.getAllAssets();
      expect(remaining, hasLength(1));
      expect(remaining.first.id, 'a2');
    });

    test('batchMoveToProject reassigns projectId', () async {
      await _seedProject('proj1');
      await dao.insertAsset(_makeAsset('a1', 'One'));
      await dao.insertAsset(_makeAsset('a2', 'Two'));

      await dao.batchMoveToProject(['a1', 'a2'], 'proj1');
      final moved = await dao.getByProject('proj1');
      expect(moved, hasLength(2));
    });

    test('batchToggleFavorite sets favorite on multiple', () async {
      await dao.insertAsset(_makeAsset('a1', 'X'));
      await dao.insertAsset(_makeAsset('a2', 'Y'));

      await dao.batchToggleFavorite(['a1', 'a2'], favorite: true);
      final all = await dao.getAllAssets();
      expect(all.every((a) => a.isFavorite), isTrue);
    });

    test('countAllAssets returns total count', () async {
      expect(await dao.countAllAssets(), 0);
      await dao.insertAsset(_makeAsset('a1', 'One'));
      await dao.insertAsset(_makeAsset('a2', 'Two'));
      expect(await dao.countAllAssets(), 2);
    });
  });
}
