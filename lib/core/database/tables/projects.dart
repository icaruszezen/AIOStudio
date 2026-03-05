import 'package:drift/drift.dart';

class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get coverImagePath => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
