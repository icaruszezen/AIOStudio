import 'package:drift/drift.dart';

import 'assets.dart';
import 'projects.dart';

class AiTasks extends Table {
  TextColumn get id => text()();
  TextColumn get projectId => text().nullable().references(Projects, #id)();
  TextColumn get type => text()();
  TextColumn get status => text()();
  TextColumn get provider => text()();
  TextColumn get model => text().nullable()();
  TextColumn get inputPrompt => text().nullable()();
  TextColumn get inputParams => text().nullable()();
  TextColumn get outputText => text().nullable()();
  TextColumn get outputAssetId => text().nullable().references(Assets, #id)();
  TextColumn get errorMessage => text().nullable()();
  IntColumn get tokenUsage => integer().nullable()();
  RealColumn get costEstimate => real().nullable()();
  IntColumn get startedAt => integer().nullable()();
  IntColumn get completedAt => integer().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
