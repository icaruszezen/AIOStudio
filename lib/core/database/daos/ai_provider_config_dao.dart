import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/ai_provider_configs.dart';

part 'ai_provider_config_dao.g.dart';

@DriftAccessor(tables: [AiProviderConfigs])
class AiProviderConfigDao extends DatabaseAccessor<AppDatabase>
    with _$AiProviderConfigDaoMixin {
  AiProviderConfigDao(super.db);

  Future<List<AiProviderConfig>> getAll() => select(aiProviderConfigs).get();

  Stream<List<AiProviderConfig>> watchAll() =>
      select(aiProviderConfigs).watch();

  Future<AiProviderConfig?> getById(String id) => (select(
    aiProviderConfigs,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<AiProviderConfig>> getEnabled() =>
      (select(aiProviderConfigs)..where((t) => t.isEnabled.equals(true))).get();

  Stream<List<AiProviderConfig>> watchEnabled() => (select(
    aiProviderConfigs,
  )..where((t) => t.isEnabled.equals(true))).watch();

  Future<List<AiProviderConfig>> getByType(String type) =>
      (select(aiProviderConfigs)..where((t) => t.type.equals(type))).get();

  Future<int> insertConfig(AiProviderConfigsCompanion entry) =>
      into(aiProviderConfigs).insert(entry);

  Future<bool> updateConfig(AiProviderConfigsCompanion entry) =>
      update(aiProviderConfigs).replace(entry);

  Future<void> updateEnabled(String id, bool enabled) =>
      (update(aiProviderConfigs)..where((t) => t.id.equals(id))).write(
        AiProviderConfigsCompanion(
          isEnabled: Value(enabled),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );

  Future<int> deleteConfig(String id) =>
      (delete(aiProviderConfigs)..where((t) => t.id.equals(id))).go();
}
