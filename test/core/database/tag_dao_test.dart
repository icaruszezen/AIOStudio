@TestOn('vm')
library;

import 'package:aio_studio/core/database/app_database.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late TagDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = db.tagDao;
  });

  tearDown(() async {
    await db.close();
  });

  int now() => DateTime.now().millisecondsSinceEpoch;

  TagsCompanion makeTag(String id, String name, {int? color}) {
    return TagsCompanion(
      id: Value(id),
      name: Value(name),
      color: Value(color),
      createdAt: Value(now()),
    );
  }

  AssetsCompanion makeAsset(String id, String name) {
    final ts = now();
    return AssetsCompanion(
      id: Value(id),
      name: Value(name),
      type: const Value('image'),
      filePath: Value('/path/$id'),
      sourceType: const Value('local'),
      createdAt: Value(ts),
      updatedAt: Value(ts),
    );
  }

  group('TagDao', () {
    test('insertTag and getAllTags', () async {
      await dao.insertTag(makeTag('t1', 'Nature'));
      await dao.insertTag(makeTag('t2', 'Portrait'));

      final all = await dao.getAllTags();
      expect(all, hasLength(2));
      expect(all.map((t) => t.name), containsAll(['Nature', 'Portrait']));
    });

    test('getTagById returns correct tag', () async {
      await dao.insertTag(makeTag('t1', 'Landscape', color: 0xFF00FF00));

      final tag = await dao.getTagById('t1');
      expect(tag, isNotNull);
      expect(tag!.name, 'Landscape');
      expect(tag.color, 0xFF00FF00);

      expect(await dao.getTagById('nonexistent'), isNull);
    });

    test('updateTag replaces the row', () async {
      await dao.insertTag(makeTag('t1', 'OldName'));

      final original = await dao.getTagById('t1');
      final ok = await dao.updateTag(TagsCompanion(
        id: const Value('t1'),
        name: const Value('NewName'),
        color: const Value(0xFFFF0000),
        createdAt: Value(original!.createdAt),
      ));
      expect(ok, isTrue);

      final fetched = await dao.getTagById('t1');
      expect(fetched!.name, 'NewName');
      expect(fetched.color, 0xFFFF0000);
    });

    test('deleteTag removes the row', () async {
      await dao.insertTag(makeTag('t1', 'Temp'));
      await dao.deleteTag('t1');
      expect(await dao.getAllTags(), isEmpty);
    });

    test('addTagToAsset and getTagsForAsset', () async {
      await dao.insertTag(makeTag('t1', 'Tag A'));
      await dao.insertTag(makeTag('t2', 'Tag B'));
      await db.assetDao.insertAsset(makeAsset('a1', 'Asset One'));

      await dao.addTagToAsset('a1', 't1');
      await dao.addTagToAsset('a1', 't2');

      final tags = await dao.getTagsForAsset('a1');
      expect(tags, hasLength(2));
      expect(tags.map((t) => t.id), containsAll(['t1', 't2']));
    });

    test('getAssetsForTag returns tagged assets', () async {
      await dao.insertTag(makeTag('t1', 'Shared'));
      await db.assetDao.insertAsset(makeAsset('a1', 'First'));
      await db.assetDao.insertAsset(makeAsset('a2', 'Second'));

      await dao.addTagToAsset('a1', 't1');
      await dao.addTagToAsset('a2', 't1');

      final assets = await dao.getAssetsForTag('t1');
      expect(assets, hasLength(2));
    });

    test('removeTagFromAsset breaks the link', () async {
      await dao.insertTag(makeTag('t1', 'Removable'));
      await db.assetDao.insertAsset(makeAsset('a1', 'Asset'));
      await dao.addTagToAsset('a1', 't1');

      await dao.removeTagFromAsset('a1', 't1');
      final tags = await dao.getTagsForAsset('a1');
      expect(tags, isEmpty);
    });

    test('batchAddTagToAssets tags multiple assets', () async {
      await dao.insertTag(makeTag('t1', 'Bulk'));
      await db.assetDao.insertAsset(makeAsset('a1', 'X'));
      await db.assetDao.insertAsset(makeAsset('a2', 'Y'));
      await db.assetDao.insertAsset(makeAsset('a3', 'Z'));

      await dao.batchAddTagToAssets(['a1', 'a2', 'a3'], 't1');

      final assets = await dao.getAssetsForTag('t1');
      expect(assets, hasLength(3));
    });

    test('removeAllTagsForAsset clears all associations', () async {
      await dao.insertTag(makeTag('t1', 'One'));
      await dao.insertTag(makeTag('t2', 'Two'));
      await db.assetDao.insertAsset(makeAsset('a1', 'Asset'));

      await dao.addTagToAsset('a1', 't1');
      await dao.addTagToAsset('a1', 't2');
      expect(await dao.getTagsForAsset('a1'), hasLength(2));

      await dao.removeAllTagsForAsset('a1');
      expect(await dao.getTagsForAsset('a1'), isEmpty);
    });
  });
}
