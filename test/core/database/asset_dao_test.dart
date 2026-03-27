@TestOn('vm')
library;

import 'package:aio_studio/core/database/app_database.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

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

  int now() => DateTime.now().millisecondsSinceEpoch;

  AssetsCompanion makeAsset(
    String id,
    String name, {
    String type = 'image',
    String? projectId,
    bool isFavorite = false,
  }) {
    final ts = now();
    return AssetsCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      filePath: Value('/path/$id'),
      sourceType: const Value('local'),
      createdAt: Value(ts),
      updatedAt: Value(ts),
      projectId: Value(projectId),
      isFavorite: Value(isFavorite),
    );
  }

  Future<void> seedProject(String id) async {
    final ts = now();
    await db.projectDao.insertProject(
      ProjectsCompanion(
        id: Value(id),
        name: Value('Project $id'),
        createdAt: Value(ts),
        updatedAt: Value(ts),
      ),
    );
  }

  group('AssetDao', () {
    test('insertAsset and getAllAssets', () async {
      await dao.insertAsset(makeAsset('a1', 'Image One'));
      await dao.insertAsset(makeAsset('a2', 'Image Two'));

      final all = await dao.getAllAssets();
      expect(all, hasLength(2));
      expect(all.map((a) => a.name), containsAll(['Image One', 'Image Two']));
    });

    test('getAssetById returns correct asset', () async {
      await dao.insertAsset(makeAsset('a1', 'Photo'));

      final found = await dao.getAssetById('a1');
      expect(found, isNotNull);
      expect(found!.name, 'Photo');

      expect(await dao.getAssetById('missing'), isNull);
    });

    test('updateAsset replaces the row', () async {
      await dao.insertAsset(makeAsset('a1', 'Old'));
      final original = await dao.getAssetById('a1');

      final ok = await dao.updateAsset(
        AssetsCompanion(
          id: const Value('a1'),
          name: const Value('New'),
          type: Value(original!.type),
          filePath: Value(original.filePath),
          sourceType: Value(original.sourceType),
          createdAt: Value(original.createdAt),
          updatedAt: Value(now()),
          isFavorite: Value(original.isFavorite),
        ),
      );
      expect(ok, isTrue);

      final fetched = await dao.getAssetById('a1');
      expect(fetched!.name, 'New');
      expect(fetched.type, original.type, reason: 'type should be unchanged');
      expect(
        fetched.filePath,
        original.filePath,
        reason: 'filePath should be unchanged',
      );
      expect(
        fetched.createdAt,
        original.createdAt,
        reason: 'createdAt should be unchanged',
      );
    });

    test('deleteAsset removes the row', () async {
      await dao.insertAsset(makeAsset('a1', 'Gone'));
      await dao.deleteAsset('a1');
      expect(await dao.getAllAssets(), isEmpty);
    });

    test('getByProject filters by projectId', () async {
      await seedProject('proj1');
      await dao.insertAsset(makeAsset('a1', 'A', projectId: 'proj1'));
      await dao.insertAsset(makeAsset('a2', 'B'));

      final byProject = await dao.getByProject('proj1');
      expect(byProject, hasLength(1));
      expect(byProject.first.id, 'a1');
    });

    test('filterByType returns matching type', () async {
      await dao.insertAsset(makeAsset('a1', 'Img', type: 'image'));
      await dao.insertAsset(makeAsset('a2', 'Vid', type: 'video'));
      await dao.insertAsset(makeAsset('a3', 'Img2', type: 'image'));

      final images = await dao.filterByType('image');
      expect(images, hasLength(2));

      final videos = await dao.filterByType('video');
      expect(videos, hasLength(1));
    });

    test('toggleFavorite updates the flag', () async {
      await dao.insertAsset(makeAsset('a1', 'Star'));

      await dao.toggleFavorite('a1', favorite: true);
      var a = await dao.getAssetById('a1');
      expect(a!.isFavorite, isTrue);

      await dao.toggleFavorite('a1', favorite: false);
      a = await dao.getAssetById('a1');
      expect(a!.isFavorite, isFalse);
    });

    test('getPaginated respects limit and offset', () async {
      for (var i = 0; i < 10; i++) {
        await dao.insertAsset(makeAsset('a$i', 'Asset $i'));
      }

      final page1 = await dao.getPaginated(limit: 3, offset: 0);
      expect(page1, hasLength(3));

      final page2 = await dao.getPaginated(limit: 3, offset: 3);
      expect(page2, hasLength(3));

      final page1Ids = page1.map((a) => a.id).toSet();
      final page2Ids = page2.map((a) => a.id).toSet();
      expect(
        page1Ids.intersection(page2Ids),
        isEmpty,
        reason: 'Pages should not overlap',
      );

      final lastPage = await dao.getPaginated(limit: 5, offset: 8);
      expect(lastPage, hasLength(2));
    });

    test('countByProject and countByProjectAndType', () async {
      await seedProject('proj1');
      await dao.insertAsset(
        makeAsset('a1', 'I1', type: 'image', projectId: 'proj1'),
      );
      await dao.insertAsset(
        makeAsset('a2', 'V1', type: 'video', projectId: 'proj1'),
      );
      await dao.insertAsset(
        makeAsset('a3', 'I2', type: 'image', projectId: 'proj1'),
      );

      expect(await dao.countByProject('proj1'), 3);
      expect(await dao.countByProjectAndType('proj1', 'image'), 2);
      expect(await dao.countByProjectAndType('proj1', 'video'), 1);
    });

    test('searchByName finds matching names', () async {
      await dao.insertAsset(makeAsset('a1', 'sunset_photo'));
      await dao.insertAsset(makeAsset('a2', 'mountain_photo'));
      await dao.insertAsset(makeAsset('a3', 'logo_design'));

      final results = await dao.searchByName('photo');
      expect(results, hasLength(2));
    });

    test('batchDelete removes multiple assets', () async {
      await dao.insertAsset(makeAsset('a1', 'One'));
      await dao.insertAsset(makeAsset('a2', 'Two'));
      await dao.insertAsset(makeAsset('a3', 'Three'));

      await dao.batchDelete(['a1', 'a3']);
      final remaining = await dao.getAllAssets();
      expect(remaining, hasLength(1));
      expect(remaining.first.id, 'a2');
    });

    test('batchMoveToProject reassigns projectId', () async {
      await seedProject('proj1');
      await seedProject('proj2');
      await dao.insertAsset(makeAsset('a1', 'One', projectId: 'proj1'));
      await dao.insertAsset(makeAsset('a2', 'Two', projectId: 'proj1'));
      await dao.insertAsset(makeAsset('a3', 'Three', projectId: 'proj1'));

      await dao.batchMoveToProject(['a1', 'a2'], 'proj2');

      final inProj2 = await dao.getByProject('proj2');
      expect(inProj2, hasLength(2));
      expect(inProj2.map((a) => a.id), containsAll(['a1', 'a2']));

      final inProj1 = await dao.getByProject('proj1');
      expect(inProj1, hasLength(1));
      expect(inProj1.first.id, 'a3');
    });

    test('batchToggleFavorite sets favorite on multiple', () async {
      await dao.insertAsset(makeAsset('a1', 'X'));
      await dao.insertAsset(makeAsset('a2', 'Y'));

      await dao.batchToggleFavorite(['a1', 'a2'], favorite: true);
      final all = await dao.getAllAssets();
      expect(all.every((a) => a.isFavorite), isTrue);
    });

    test('countAllAssets returns total count', () async {
      expect(await dao.countAllAssets(), 0);
      await dao.insertAsset(makeAsset('a1', 'One'));
      await dao.insertAsset(makeAsset('a2', 'Two'));
      expect(await dao.countAllAssets(), 2);
    });
  });
}
