import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import 'asset_filter_provider.dart';

final currentAssetIdProvider =
    NotifierProvider<CurrentAssetIdNotifier, String?>(
  CurrentAssetIdNotifier.new,
);

class CurrentAssetIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  // ignore: use_setters_to_change_properties
  void set(String? id) => state = id;
}

final _currentAssetIndexProvider = Provider<(int index, List<Asset> assets)>((ref) {
  final currentId = ref.watch(currentAssetIdProvider);
  if (currentId == null) return (-1, const []);

  final filteredAsync = ref.watch(filteredAssetsProvider);
  final List<Asset> assets = filteredAsync.value ?? [];
  final index = assets.indexWhere((a) => a.id == currentId);
  return (index, assets);
});

final previousAssetIdProvider = Provider<String?>((ref) {
  final (index, assets) = ref.watch(_currentAssetIndexProvider);
  if (index <= 0) return null;
  return assets[index - 1].id;
});

final nextAssetIdProvider = Provider<String?>((ref) {
  final (index, assets) = ref.watch(_currentAssetIndexProvider);
  if (index < 0 || index >= assets.length - 1) return null;
  return assets[index + 1].id;
});

final assetNavigationInfoProvider = Provider<String>((ref) {
  final (index, assets) = ref.watch(_currentAssetIndexProvider);
  if (index < 0) return '';
  return '${index + 1} / ${assets.length}';
});
