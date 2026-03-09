import 'package:drift/drift.dart';

class AiProviderConfigs extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  /// Kept for backward compatibility; new API keys are stored via
  /// [SecureKeyService] and this column remains null.
  TextColumn get apiKey => text().nullable()();
  TextColumn get baseUrl => text().nullable()();
  TextColumn get defaultModel => text().nullable()();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  TextColumn get extraConfig => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
