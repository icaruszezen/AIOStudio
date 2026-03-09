import 'package:drift/drift.dart' show Value;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

import '../database/app_database.dart';

class SecureKeyService {
  static final _log = Logger(printer: PrettyPrinter(methodCount: 0));
  static const _prefix = 'aio_api_key_';

  final FlutterSecureStorage _storage;

  SecureKeyService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  String _key(String providerId) => '$_prefix$providerId';

  Future<void> saveApiKey(String providerId, String apiKey) async {
    await _storage.write(key: _key(providerId), value: apiKey);
  }

  Future<String?> getApiKey(String providerId) async {
    return _storage.read(key: _key(providerId));
  }

  Future<void> deleteApiKey(String providerId) async {
    await _storage.delete(key: _key(providerId));
  }

  Future<bool> hasApiKey(String providerId) async {
    final value = await _storage.read(key: _key(providerId));
    return value != null && value.isNotEmpty;
  }

  /// One-time migration: moves plaintext API keys from the database into
  /// secure storage, then clears the database column.
  Future<void> migrateFromDatabase(AiProviderConfigDao dao) async {
    try {
      final configs = await dao.getAll();
      var migrated = 0;

      for (final cfg in configs) {
        if (cfg.apiKey != null && cfg.apiKey!.isNotEmpty) {
          final existing = await getApiKey(cfg.id);
          if (existing == null || existing.isEmpty) {
            await saveApiKey(cfg.id, cfg.apiKey!);
          }

          await dao.updateConfig(
            AiProviderConfigsCompanion(
              id: Value(cfg.id),
              name: Value(cfg.name),
              type: Value(cfg.type),
              apiKey: const Value(null),
              baseUrl: Value(cfg.baseUrl),
              defaultModel: Value(cfg.defaultModel),
              isEnabled: Value(cfg.isEnabled),
              extraConfig: Value(cfg.extraConfig),
              createdAt: Value(cfg.createdAt),
              updatedAt: Value(cfg.updatedAt),
            ),
          );
          migrated++;
        }
      }

      if (migrated > 0) {
        _log.i('[SecureKeyService] Migrated $migrated API key(s) '
            'to secure storage');
      }
    } catch (e) {
      _log.e('[SecureKeyService] Migration failed: $e');
    }
  }
}
