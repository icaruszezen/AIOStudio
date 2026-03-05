import 'package:drift/drift.dart';

import 'projects.dart';

class Prompts extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().nullable().references(Projects, #id)();
  TextColumn get title => text()();
  TextColumn get content => text()();
  TextColumn get category => text().nullable()();
  TextColumn get variables => text().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  IntColumn get useCount => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
