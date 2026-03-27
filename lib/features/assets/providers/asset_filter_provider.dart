import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';

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
      projectFilter: projectFilter != null
          ? projectFilter()
          : this.projectFilter,
      tagFilters: tagFilters ?? this.tagFilters,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      searchQuery: searchQuery ?? this.searchQuery,
      viewMode: viewMode ?? this.viewMode,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssetFilterState &&
          typeFilter == other.typeFilter &&
          projectFilter == other.projectFilter &&
          tagFilters.length == other.tagFilters.length &&
          tagFilters.containsAll(other.tagFilters) &&
          sortField == other.sortField &&
          sortAscending == other.sortAscending &&
          searchQuery == other.searchQuery &&
          viewMode == other.viewMode;

  @override
  int get hashCode => Object.hash(
    typeFilter,
    projectFilter,
    Object.hashAll(tagFilters.toList()..sort()),
    sortField,
    sortAscending,
    searchQuery,
    viewMode,
  );
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

final assetFilterProvider =
    NotifierProvider<AssetFilterNotifier, AssetFilterState>(
      AssetFilterNotifier.new,
    );

class AssetFilterNotifier extends Notifier<AssetFilterState> {
  Timer? _debounce;

  @override
  AssetFilterState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const AssetFilterState();
  }

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

  void setSearchQuery(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      state = state.copyWith(searchQuery: query);
    });
  }

  void setViewMode(AssetViewMode mode) =>
      state = state.copyWith(viewMode: mode);

  void clearAll() {
    _debounce?.cancel();
    state = const AssetFilterState();
  }
}

// ---------------------------------------------------------------------------
// SQL-backed filtered assets stream
// ---------------------------------------------------------------------------

final filteredAssetsProvider = StreamProvider.autoDispose<List<Asset>>((ref) {
  final typeFilter = ref.watch(assetFilterProvider.select((s) => s.typeFilter));
  final projectFilter = ref.watch(
    assetFilterProvider.select((s) => s.projectFilter),
  );
  final tagFilters = ref.watch(assetFilterProvider.select((s) => s.tagFilters));
  final searchQuery = ref.watch(
    assetFilterProvider.select((s) => s.searchQuery),
  );
  final sortField = ref.watch(assetFilterProvider.select((s) => s.sortField));
  final sortAscending = ref.watch(
    assetFilterProvider.select((s) => s.sortAscending),
  );
  final dao = ref.watch(assetDaoProvider);

  final sortColumn = switch (sortField) {
    AssetSortField.name => 'name',
    AssetSortField.createdAt => 'createdAt',
    AssetSortField.fileSize => 'fileSize',
    AssetSortField.type => 'type',
  };

  return dao.watchFiltered(
    typeFilter: typeFilter,
    projectFilter: projectFilter,
    tagIds: tagFilters,
    searchQuery: searchQuery,
    sortColumn: sortColumn,
    sortAscending: sortAscending,
  );
});
