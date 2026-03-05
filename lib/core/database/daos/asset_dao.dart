import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/asset_tags.dart';
import '../tables/assets.dart';

part 'asset_dao.g.dart';

@DriftAccessor(tables: [Assets, AssetTags])
class AssetDao extends DatabaseAccessor<AppDatabase> with _$AssetDaoMixin {
  AssetDao(super.db);

  Future<List<Asset>> getAllAssets() => select(assets).get();

  Stream<List<Asset>> watchAllAssets() => select(assets).watch();

  Future<Asset?> getAssetById(String id) =>
      (select(assets)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertAsset(AssetsCompanion entry) =>
      into(assets).insert(entry);

  Future<bool> updateAsset(AssetsCompanion entry) =>
      update(assets).replace(entry);

  Future<int> deleteAsset(String id) =>
      (delete(assets)..where((t) => t.id.equals(id))).go();

  Future<List<Asset>> getByProject(String projectId) =>
      (select(assets)..where((t) => t.projectId.equals(projectId))).get();

  Stream<List<Asset>> watchByProject(String projectId) =>
      (select(assets)..where((t) => t.projectId.equals(projectId))).watch();

  Future<List<Asset>> filterByType(String type) =>
      (select(assets)..where((t) => t.type.equals(type))).get();

  Future<List<Asset>> filterByTags(List<String> tagIds) async {
    final query = select(assets).join([
      innerJoin(assetTags, assetTags.assetId.equalsExp(assets.id)),
    ])
      ..where(assetTags.tagId.isIn(tagIds))
      ..groupBy([assets.id]);
    final rows = await query.get();
    return rows.map((r) => r.readTable(assets)).toList();
  }

  Future<void> toggleFavorite(String id, {required bool favorite}) =>
      (update(assets)..where((t) => t.id.equals(id))).write(
        AssetsCompanion(isFavorite: Value(favorite)),
      );

  Future<List<Asset>> getPaginated({
    required int limit,
    required int offset,
    String? projectId,
  }) {
    final query = select(assets)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ..limit(limit, offset: offset);
    if (projectId != null) {
      query.where((t) => t.projectId.equals(projectId));
    }
    return query.get();
  }

  Future<int> countByProject(String projectId) async {
    final count = countAll();
    final query = selectOnly(assets)..addColumns([count]);
    query.where(assets.projectId.equals(projectId));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  Future<int> countByProjectAndType(String projectId, String type) async {
    final count = countAll();
    final query = selectOnly(assets)..addColumns([count]);
    query.where(
      assets.projectId.equals(projectId) & assets.type.equals(type),
    );
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }
}
