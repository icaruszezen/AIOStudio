import 'package:drift/drift.dart';

import 'projects.dart';

class Assets extends Table {
  TextColumn get id => text()();
  TextColumn get projectId => text().nullable().references(Projects, #id)();
  TextColumn get name => text()();
  TextColumn get type => text()();
  TextColumn get filePath => text()();
  TextColumn get thumbnailPath => text().nullable()();
  TextColumn get originalUrl => text().nullable()();
  TextColumn get sourceType => text()();
  IntColumn get fileSize => integer().nullable()();
  IntColumn get width => integer().nullable()();
  IntColumn get height => integer().nullable()();
  RealColumn get duration => real().nullable()();
  TextColumn get metadata => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
