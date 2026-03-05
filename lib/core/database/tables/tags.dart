import 'package:drift/drift.dart';

class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get color => integer().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {name},
      ];
}
