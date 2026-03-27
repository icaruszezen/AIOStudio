import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';

// ---------------------------------------------------------------------------
// Stream providers
// ---------------------------------------------------------------------------

final allTagsProvider = StreamProvider<List<Tag>>((ref) {
  return ref.watch(tagDaoProvider).watchAllTags();
});

final tagsForAssetProvider = StreamProvider.autoDispose
    .family<List<Tag>, String>((ref, assetId) {
      return ref.watch(tagDaoProvider).watchTagsForAsset(assetId);
    });

final allAssetTagsProvider = StreamProvider<List<AssetTag>>((ref) {
  return ref.watch(tagDaoProvider).watchAllAssetTags();
});

// ---------------------------------------------------------------------------
// Tag actions
// ---------------------------------------------------------------------------

final tagActionsProvider = Provider<TagActions>((ref) {
  return TagActions(ref);
});

class TagActions {
  TagActions(this._ref);

  final Ref _ref;
  static const _uuid = Uuid();

  Future<String> create({required String name, int? color}) async {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _ref
        .read(tagDaoProvider)
        .insertTag(
          TagsCompanion.insert(
            id: id,
            name: name,
            color: Value(color),
            createdAt: now,
          ),
        );
    return id;
  }

  Future<void> update({required String id, String? name, int? color}) async {
    final dao = _ref.read(tagDaoProvider);
    final existing = await dao.getTagById(id);
    if (existing == null) return;

    await dao.updateTag(
      TagsCompanion(
        id: Value(existing.id),
        name: Value(name ?? existing.name),
        color: Value(color ?? existing.color),
        createdAt: Value(existing.createdAt),
      ),
    );
  }

  Future<void> deleteTag(String id) => _ref.read(tagDaoProvider).deleteTag(id);

  Future<void> addToAsset(String assetId, String tagId) =>
      _ref.read(tagDaoProvider).addTagToAsset(assetId, tagId);

  Future<void> removeFromAsset(String assetId, String tagId) =>
      _ref.read(tagDaoProvider).removeTagFromAsset(assetId, tagId);

  Future<void> batchAddToAssets(List<String> assetIds, String tagId) =>
      _ref.read(tagDaoProvider).batchAddTagToAssets(assetIds, tagId);
}
