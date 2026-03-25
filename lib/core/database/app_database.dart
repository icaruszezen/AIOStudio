import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../constants/app_constants.dart';

import 'daos/ai_provider_config_dao.dart';
import 'daos/ai_task_dao.dart';
import 'daos/asset_dao.dart';
import 'daos/project_dao.dart';
import 'daos/prompt_dao.dart';
import 'daos/tag_dao.dart';
import 'tables/ai_provider_configs.dart';
import 'tables/ai_tasks.dart';
import 'tables/asset_tags.dart';
import 'tables/assets.dart';
import 'tables/projects.dart';
import 'tables/prompts.dart';
import 'tables/tags.dart';

export 'daos/ai_provider_config_dao.dart';
export 'daos/ai_task_dao.dart';
export 'daos/asset_dao.dart';
export 'daos/project_dao.dart';
export 'daos/prompt_dao.dart';
export 'daos/tag_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Projects,
    Assets,
    Tags,
    AssetTags,
    Prompts,
    AiTasks,
    AiProviderConfigs,
  ],
  daos: [
    ProjectDao,
    AssetDao,
    TagDao,
    PromptDao,
    AiTaskDao,
    AiProviderConfigDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          await customStatement('PRAGMA journal_mode = WAL');
          await customStatement('PRAGMA synchronous = NORMAL');
          await customStatement('PRAGMA busy_timeout = 5000');
        },
        onCreate: (m) async {
          await m.createAll();
          await _createIndexesV1(customStatement);
          await _createIndexesV2(customStatement);
          await _createIndexesV3(customStatement);
        },
        onUpgrade: (m, from, to) async {
          for (var target = from + 1; target <= to; target++) {
            switch (target) {
              case 2:
                await _createIndexesV2(customStatement);
              case 3:
                await _createIndexesV3(customStatement);
            }
          }
        },
      );

  static Future<void> _createIndexesV1(
      Future<void> Function(String, [List<dynamic>?]) exec) async {
    await exec(
        'CREATE INDEX IF NOT EXISTS idx_assets_project_id ON assets(project_id)');
    await exec(
        'CREATE INDEX IF NOT EXISTS idx_assets_type ON assets(type)');
    await exec(
        'CREATE INDEX IF NOT EXISTS idx_assets_created_at ON assets(created_at)');
    await exec(
        'CREATE INDEX IF NOT EXISTS idx_assets_is_favorite ON assets(is_favorite)');
  }

  static Future<void> _createIndexesV2(
      Future<void> Function(String, [List<dynamic>?]) exec) async {
    await exec(
        'CREATE INDEX IF NOT EXISTS idx_ai_tasks_project_id ON ai_tasks(project_id)');
    await exec(
        'CREATE INDEX IF NOT EXISTS idx_ai_tasks_status ON ai_tasks(status)');
    await exec(
        'CREATE INDEX IF NOT EXISTS idx_ai_tasks_created_at ON ai_tasks(created_at)');
    await exec(
        'CREATE INDEX IF NOT EXISTS idx_prompts_project_id ON prompts(project_id)');
    await exec(
        'CREATE INDEX IF NOT EXISTS idx_prompts_category ON prompts(category)');
    await exec(
        'CREATE INDEX IF NOT EXISTS idx_asset_tags_tag_id ON asset_tags(tag_id)');
    await exec(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_ai_provider_configs_name_type '
        'ON ai_provider_configs(name, type)');
  }

  static Future<void> _createIndexesV3(
      Future<void> Function(String, [List<dynamic>?]) exec) async {
    await exec(
        'CREATE INDEX IF NOT EXISTS idx_projects_archived_updated '
        'ON projects(is_archived, updated_at)');
    await exec(
        'CREATE INDEX IF NOT EXISTS idx_prompts_favorite_updated '
        'ON prompts(is_favorite, updated_at)');
    await exec(
        'CREATE INDEX IF NOT EXISTS idx_ai_tasks_type_created '
        'ON ai_tasks(type, created_at)');
    await exec(
        'CREATE INDEX IF NOT EXISTS idx_ai_tasks_provider '
        'ON ai_tasks(provider)');
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, AppConstants.databaseFileName));
    return NativeDatabase.createInBackground(file);
  });
}
