import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../services/secure_key_service.dart';
import '../services/storage/asset_file_manager.dart';
import '../services/storage/local_storage_service.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final projectDaoProvider = Provider<ProjectDao>((ref) {
  return ref.watch(appDatabaseProvider).projectDao;
});

final assetDaoProvider = Provider<AssetDao>((ref) {
  return ref.watch(appDatabaseProvider).assetDao;
});

final tagDaoProvider = Provider<TagDao>((ref) {
  return ref.watch(appDatabaseProvider).tagDao;
});

final promptDaoProvider = Provider<PromptDao>((ref) {
  return ref.watch(appDatabaseProvider).promptDao;
});

final aiTaskDaoProvider = Provider<AiTaskDao>((ref) {
  return ref.watch(appDatabaseProvider).aiTaskDao;
});

final aiProviderConfigDaoProvider = Provider<AiProviderConfigDao>((ref) {
  return ref.watch(appDatabaseProvider).aiProviderConfigDao;
});

final secureKeyServiceProvider = Provider<SecureKeyService>((ref) {
  return SecureKeyService();
});

final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  return LocalStorageService();
});

final assetFileManagerProvider = Provider<AssetFileManager>((ref) {
  return AssetFileManager(
    assetDao: ref.watch(assetDaoProvider),
    storage: ref.watch(localStorageServiceProvider),
  );
});
