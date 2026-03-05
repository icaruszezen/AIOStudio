import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import 'assets_provider.dart';
import 'tags_provider.dart';

// ---------------------------------------------------------------------------
// Enums & state
// ---------------------------------------------------------------------------

enum AssetViewMode { grid, list }

enum AssetSortField { name, createdAt, fileSize, type }

class AssetFilterState {
  const AssetFilterState({
    this.typeFilter,
    this.projectFilter,
    this.tagFilters = const {},
    this.sortField = AssetSortField.createdAt,
    this.sortAscending = false,
    this.searchQuery = '',
    this.viewMode = AssetViewMode.grid,
  });

  final String? typeFilter;
  final String? projectFilter;
  final Set<String> tagFilters;
  final AssetSortField sortField;
  final bool sortAscending;
  final String searchQuery;
  final AssetViewMode viewMode;

  bool get hasActiveFilters =>
      typeFilter != null ||
      projectFilter != null ||
      tagFilters.isNotEmpty ||
      searchQuery.isNotEmpty;

  AssetFilterState copyWith({
    String? Function()? typeFilter,
    String? Function()? projectFilter,
    Set<String>? tagFilters,
    AssetSortField? sortField,
    bool? sortAscending,
    String? searchQuery,
    AssetViewMode? viewMode,
  }) {
    return AssetFilterState(
      typeFilter: typeFilter != null ? typeFilter() : this.typeFilter,
      projectFilter:
          projectFilter != null ? projectFilter() : this.projectFilter,
      tagFilters: tagFilters ?? this.tagFilters,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      searchQuery: searchQuery ?? this.searchQuery,
      viewMode: viewMode ?? this.viewMode,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

final assetFilterProvider =
    NotifierProvider<AssetFilterNotifier, AssetFilterState>(
  AssetFilterNotifier.new,
);

class AssetFilterNotifier extends Notifier<AssetFilterState> {
  @override
  AssetFilterState build() => const AssetFilterState();

  void setTypeFilter(String? type) =>
      state = state.copyWith(typeFilter: () => type);

  void setProjectFilter(String? projectId) =>
      state = state.copyWith(projectFilter: () => projectId);

  void toggleTagFilter(String tagId) {
    final tags = Set<String>.from(state.tagFilters);
    if (tags.contains(tagId)) {
      tags.remove(tagId);
    } else {
      tags.add(tagId);
    }
    state = state.copyWith(tagFilters: tags);
  }

  void removeTagFilter(String tagId) {
    final tags = Set<String>.from(state.tagFilters)..remove(tagId);
    state = state.copyWith(tagFilters: tags);
  }

  void setSortField(AssetSortField field) =>
      state = state.copyWith(sortField: field);

  void toggleSortDirection() =>
      state = state.copyWith(sortAscending: !state.sortAscending);

  void setSearchQuery(String query) =>
      state = state.copyWith(searchQuery: query);

  void setViewMode(AssetViewMode mode) =>
      state = state.copyWith(viewMode: mode);

  void clearAll() => state = const AssetFilterState();
}

// ---------------------------------------------------------------------------
// Combined filtered assets
// ---------------------------------------------------------------------------

final filteredAssetsProvider = Provider<AsyncValue<List<Asset>>>((ref) {
  final filter = ref.watch(assetFilterProvider);
  final assetsAsync = ref.watch(allAssetsProvider);
  final assetTagsAsync = ref.watch(allAssetTagsProvider);

  return assetsAsync.when(
    loading: () => const AsyncValue<List<Asset>>.loading(),
    error: AsyncValue<List<Asset>>.error,
    data: (assets) {
      final assetTags = assetTagsAsync.value ?? <AssetTag>[];

      var filtered = List<Asset>.from(assets);

      if (filter.typeFilter != null) {
        filtered = filtered.where((a) => a.type == filter.typeFilter).toList();
      }

      if (filter.projectFilter != null) {
        filtered = filtered
            .where((a) => a.projectId == filter.projectFilter)
            .toList();
      }

      if (filter.tagFilters.isNotEmpty) {
        final assetIdsWithTags = <String>{};
        for (final at in assetTags) {
          if (filter.tagFilters.contains(at.tagId)) {
            assetIdsWithTags.add(at.assetId);
          }
        }
        filtered =
            filtered.where((a) => assetIdsWithTags.contains(a.id)).toList();
      }

      if (filter.searchQuery.isNotEmpty) {
        final query = filter.searchQuery.toLowerCase();
        filtered = filtered
            .where((a) => a.name.toLowerCase().contains(query))
            .toList();
      }

      filtered.sort((a, b) {
        final cmp = switch (filter.sortField) {
          AssetSortField.name => a.name.compareTo(b.name),
          AssetSortField.createdAt => a.createdAt.compareTo(b.createdAt),
          AssetSortField.fileSize =>
            (a.fileSize ?? 0).compareTo(b.fileSize ?? 0),
          AssetSortField.type => a.type.compareTo(b.type),
        };
        return filter.sortAscending ? cmp : -cmp;
      });

      return AsyncValue<List<Asset>>.data(filtered);
    },
  );
});
