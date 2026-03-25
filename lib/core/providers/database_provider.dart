import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_config_provider.dart';
import '../database/app_database.dart';
import '../services/secure_key_service.dart';
import '../services/storage/asset_file_manager.dart';
import '../services/storage/local_storage_service.dart';

// ---------------------------------------------------------------------------
// Shared cross-module data providers
// ---------------------------------------------------------------------------

/// Streams active (non-archived) projects, newest updates first.
final activeProjectsProvider = StreamProvider<List<Project>>((ref) {
  return ref.watch(projectDaoProvider).watchActiveProjects();
});

// ---------------------------------------------------------------------------
// Database & DAO providers
// ---------------------------------------------------------------------------

/// Provides the shared [AppDatabase] and closes it on dispose.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Provides access to the [ProjectDao] for database operations.
final projectDaoProvider = Provider<ProjectDao>((ref) {
  return ref.watch(appDatabaseProvider).projectDao;
});

/// Provides access to the [AssetDao] for database operations.
final assetDaoProvider = Provider<AssetDao>((ref) {
  return ref.watch(appDatabaseProvider).assetDao;
});

/// Provides access to the [TagDao] for database operations.
final tagDaoProvider = Provider<TagDao>((ref) {
  return ref.watch(appDatabaseProvider).tagDao;
});

/// Provides access to the [PromptDao] for database operations.
final promptDaoProvider = Provider<PromptDao>((ref) {
  return ref.watch(appDatabaseProvider).promptDao;
});

/// Provides access to the [AiTaskDao] for database operations.
final aiTaskDaoProvider = Provider<AiTaskDao>((ref) {
  return ref.watch(appDatabaseProvider).aiTaskDao;
});

/// Provides access to the [AiProviderConfigDao] for database operations.
final aiProviderConfigDaoProvider = Provider<AiProviderConfigDao>((ref) {
  return ref.watch(appDatabaseProvider).aiProviderConfigDao;
});

/// Provides a [SecureKeyService] for storing and reading secrets.
final secureKeyServiceProvider = Provider<SecureKeyService>((ref) {
  return SecureKeyService();
});

/// Provides [LocalStorageService] rooted at [storageDirectoryProvider].
final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  final customDir = ref.watch(storageDirectoryProvider);
  return LocalStorageService(cacheDirectory: customDir);
});

/// Provides [AssetFileManager] using the asset DAO and local storage service.
final assetFileManagerProvider = Provider<AssetFileManager>((ref) {
  return AssetFileManager(
    assetDao: ref.watch(assetDaoProvider),
    storage: ref.watch(localStorageServiceProvider),
  );
});
