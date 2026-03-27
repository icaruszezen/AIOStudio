import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/asset_tags.dart';
import '../tables/assets.dart';
import '../tables/tags.dart';

part 'tag_dao.g.dart';

@DriftAccessor(tables: [Tags, AssetTags, Assets])
class TagDao extends DatabaseAccessor<AppDatabase> with _$TagDaoMixin {
  TagDao(super.db);

  Future<List<Tag>> getAllTags() => select(tags).get();

  Stream<List<Tag>> watchAllTags() => select(tags).watch();

  Future<Tag?> getTagById(String id) =>
      (select(tags)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertTag(TagsCompanion entry) => into(tags).insert(entry);

  Future<bool> updateTag(TagsCompanion entry) => update(tags).replace(entry);

  Future<void> deleteTag(String id) => transaction(() async {
    await (delete(assetTags)..where((t) => t.tagId.equals(id))).go();
    await (delete(tags)..where((t) => t.id.equals(id))).go();
  });

  Future<List<Tag>> getTagsForAsset(String assetId) async {
    final query = select(tags).join([
      innerJoin(assetTags, assetTags.tagId.equalsExp(tags.id)),
    ])..where(assetTags.assetId.equals(assetId));
    final rows = await query.get();
    return rows.map((r) => r.readTable(tags)).toList();
  }

  Future<List<Asset>> getAssetsForTag(String tagId) async {
    final query = select(assets).join([
      innerJoin(assetTags, assetTags.assetId.equalsExp(assets.id)),
    ])..where(assetTags.tagId.equals(tagId));
    final rows = await query.get();
    return rows.map((r) => r.readTable(assets)).toList();
  }

  Future<int> addTagToAsset(String assetId, String tagId) => into(
    assetTags,
  ).insert(AssetTagsCompanion.insert(assetId: assetId, tagId: tagId));

  Future<int> removeTagFromAsset(String assetId, String tagId) => (delete(
    assetTags,
  )..where((t) => t.assetId.equals(assetId) & t.tagId.equals(tagId))).go();

  Stream<List<Tag>> watchTagsForAsset(String assetId) {
    final query = select(tags).join([
      innerJoin(assetTags, assetTags.tagId.equalsExp(tags.id)),
    ])..where(assetTags.assetId.equals(assetId));
    return query.watch().map(
      (rows) => rows.map((r) => r.readTable(tags)).toList(),
    );
  }

  Future<void> batchAddTagToAssets(List<String> assetIds, String tagId) =>
      batch((b) {
        for (final assetId in assetIds) {
          b.insert(
            assetTags,
            AssetTagsCompanion.insert(assetId: assetId, tagId: tagId),
            onConflict: DoNothing(),
          );
        }
      });

  Future<void> batchAddTagsToAsset(String assetId, List<String> tagIds) =>
      batch((b) {
        for (final tagId in tagIds) {
          b.insert(
            assetTags,
            AssetTagsCompanion.insert(assetId: assetId, tagId: tagId),
            onConflict: DoNothing(),
          );
        }
      });

  Stream<List<AssetTag>> watchAllAssetTags() => select(assetTags).watch();

  Future<void> removeAllTagsForAsset(String assetId) =>
      (delete(assetTags)..where((t) => t.assetId.equals(assetId))).go();
}
