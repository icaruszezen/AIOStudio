import 'package:drift/drift.dart';

import '../../utils/epoch_utils.dart';
import '../../utils/query_utils.dart';
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

  Future<int> insertAsset(AssetsCompanion entry) => into(assets).insert(entry);

  Future<bool> updateAsset(AssetsCompanion entry) =>
      update(assets).replace(entry);

  Future<void> deleteAsset(String id) => transaction(() async {
    await customStatement(
      'UPDATE ai_tasks SET output_asset_id = NULL '
      'WHERE output_asset_id = ?',
      [id],
    );
    await (delete(assetTags)..where((t) => t.assetId.equals(id))).go();
    await (delete(assets)..where((t) => t.id.equals(id))).go();
  });

  Future<List<Asset>> getByProject(String projectId) =>
      (select(assets)..where((t) => t.projectId.equals(projectId))).get();

  Stream<List<Asset>> watchByProject(String projectId) =>
      (select(assets)..where((t) => t.projectId.equals(projectId))).watch();

  Future<List<Asset>> filterByType(String type) =>
      (select(assets)..where((t) => t.type.equals(type))).get();

  /// Returns assets that have **any** of the given [tagIds] (OR semantics).
  Future<List<Asset>> filterByTags(List<String> tagIds) async {
    final query =
        select(
            assets,
          ).join([innerJoin(assetTags, assetTags.assetId.equalsExp(assets.id))])
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

  Future<Map<String, int>> countByProjects(List<String> projectIds) async {
    if (projectIds.isEmpty) return {};
    final count = countAll();
    final query = selectOnly(assets)
      ..addColumns([assets.projectId, count])
      ..where(assets.projectId.isIn(projectIds))
      ..groupBy([assets.projectId]);
    final rows = await query.get();
    return {
      for (final row in rows) row.read(assets.projectId)!: row.read(count) ?? 0,
    };
  }

  Future<int> countByProject(String projectId) async {
    final count = countAll();
    final query = selectOnly(assets)
      ..addColumns([count])
      ..where(assets.projectId.equals(projectId));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  Stream<int> watchCountByProject(String projectId) {
    final count = countAll();
    final query = selectOnly(assets)
      ..addColumns([count])
      ..where(assets.projectId.equals(projectId));
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  Future<int> countByProjectAndType(String projectId, String type) async {
    final count = countAll();
    final query = selectOnly(assets)
      ..addColumns([count])
      ..where(assets.projectId.equals(projectId) & assets.type.equals(type));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  Stream<List<Asset>> watchAssets({String? projectId}) {
    final query = select(assets)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    if (projectId != null) {
      query.where((t) => t.projectId.equals(projectId));
    }
    return query.watch();
  }

  Stream<List<Asset>> watchFavorites() =>
      (select(assets)
            ..where((t) => t.isFavorite.equals(true))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .watch();

  Future<List<Asset>> searchByName(String query) =>
      (select(assets)..where((t) => likeEscaped(t.name, query))).get();

  /// Deletes assets and their tag associations, nullifying any
  /// `ai_tasks.outputAssetId` references first.
  ///
  /// **Not** wrapped in a transaction – callers must provide one.
  Future<void> batchDelete(List<String> ids) async {
    final placeholders = List.filled(ids.length, '?').join(', ');
    await customStatement(
      'UPDATE ai_tasks SET output_asset_id = NULL '
      'WHERE output_asset_id IN ($placeholders)',
      ids,
    );
    await (delete(assetTags)..where((t) => t.assetId.isIn(ids))).go();
    await (delete(assets)..where((t) => t.id.isIn(ids))).go();
  }

  Future<void> batchMoveToProject(List<String> ids, String? projectId) =>
      (update(assets)..where((t) => t.id.isIn(ids))).write(
        AssetsCompanion(
          projectId: Value(projectId),
          updatedAt: Value(epochNowMs()),
        ),
      );

  Future<void> batchToggleFavorite(
    List<String> ids, {
    required bool favorite,
  }) => (update(assets)..where((t) => t.id.isIn(ids))).write(
    AssetsCompanion(
      isFavorite: Value(favorite),
      updatedAt: Value(epochNowMs()),
    ),
  );

  Future<int> countAllAssets() async {
    final count = countAll();
    final query = selectOnly(assets)..addColumns([count]);
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  /// Watches a single asset by its ID.
  Stream<Asset?> watchAssetById(String id) =>
      (select(assets)..where((t) => t.id.equals(id))).watchSingleOrNull();

  /// Watches assets with server-side filtering, sorting and optional tag join.
  Stream<List<Asset>> watchFiltered({
    String? typeFilter,
    String? projectFilter,
    Set<String> tagIds = const {},
    String searchQuery = '',
    String sortColumn = 'createdAt',
    bool sortAscending = false,
  }) {
    if (tagIds.isNotEmpty) {
      return _watchFilteredWithTags(
        typeFilter: typeFilter,
        projectFilter: projectFilter,
        tagIds: tagIds,
        searchQuery: searchQuery,
        sortColumn: sortColumn,
        sortAscending: sortAscending,
      );
    }

    final query = select(assets)
      ..where((t) {
        Expression<bool> expr = const Constant(true);
        if (typeFilter != null) expr = expr & t.type.equals(typeFilter);
        if (projectFilter != null) {
          expr = expr & t.projectId.equals(projectFilter);
        }
        if (searchQuery.isNotEmpty) {
          expr = expr & likeEscaped(t.name, searchQuery);
        }
        return expr;
      })
      ..orderBy([(t) => _orderTerm(t, sortColumn, sortAscending)]);

    return query.watch();
  }

  Stream<List<Asset>> _watchFilteredWithTags({
    String? typeFilter,
    String? projectFilter,
    required Set<String> tagIds,
    String searchQuery = '',
    String sortColumn = 'createdAt',
    bool sortAscending = false,
  }) {
    final query = select(
      assets,
    ).join([innerJoin(assetTags, assetTags.assetId.equalsExp(assets.id))]);

    Expression<bool> where = assetTags.tagId.isIn(tagIds.toList());
    if (typeFilter != null) where = where & assets.type.equals(typeFilter);
    if (projectFilter != null) {
      where = where & assets.projectId.equals(projectFilter);
    }
    if (searchQuery.isNotEmpty) {
      where = where & likeEscaped(assets.name, searchQuery);
    }

    query
      ..where(where)
      ..groupBy([assets.id])
      ..orderBy([_orderTerm(assets, sortColumn, sortAscending)]);

    return query.watch().map(
      (rows) => rows.map((r) => r.readTable(assets)).toList(),
    );
  }

  static OrderingTerm _orderTerm(
    $AssetsTable t,
    String sortColumn,
    bool ascending,
  ) {
    final mode = ascending ? OrderingMode.asc : OrderingMode.desc;
    return switch (sortColumn) {
      'name' => OrderingTerm(expression: t.name, mode: mode),
      'fileSize' => OrderingTerm(expression: t.fileSize, mode: mode),
      'type' => OrderingTerm(expression: t.type, mode: mode),
      _ => OrderingTerm(expression: t.createdAt, mode: mode),
    };
  }

  /// Sets all `thumbnailPath` values to NULL (used after clearing the
  /// thumbnail cache directory to avoid dangling references).
  Future<void> clearAllThumbnailPaths() async {
    await customStatement(
      'UPDATE assets SET thumbnail_path = NULL '
      'WHERE thumbnail_path IS NOT NULL',
    );
  }

  /// Replaces [oldPrefix] with [newPrefix] in cached file paths.
  /// Only touches `filePath` for non-local-import assets (downloaded /
  /// AI-generated files live in the cache dir). `thumbnailPath` is always
  /// updated since all thumbnails are cache-managed.
  Future<void> updatePathPrefix(String oldPrefix, String newPrefix) async {
    await customStatement(
      'UPDATE assets SET file_path = replace(file_path, ?, ?) '
      "WHERE source_type != 'local_import' AND file_path LIKE ?",
      [oldPrefix, newPrefix, '$oldPrefix%'],
    );
    await customStatement(
      'UPDATE assets SET thumbnail_path = replace(thumbnail_path, ?, ?) '
      'WHERE thumbnail_path IS NOT NULL AND thumbnail_path LIKE ?',
      [oldPrefix, newPrefix, '$oldPrefix%'],
    );
  }
}
