import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement(
              'CREATE INDEX idx_assets_project_id ON assets(project_id)');
          await customStatement(
              'CREATE INDEX idx_assets_type ON assets(type)');
          await customStatement(
              'CREATE INDEX idx_assets_created_at ON assets(created_at)');
          await customStatement(
              'CREATE INDEX idx_assets_is_favorite ON assets(is_favorite)');
        },
        onUpgrade: (m, from, to) async {
          for (var target = from + 1; target <= to; target++) {
            switch (target) {
              // Future migrations go here, e.g.:
              // case 2:
              //   await m.addColumn(assets, assets.newColumn);
            }
          }
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, 'aio_studio.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
