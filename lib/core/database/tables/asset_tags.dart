import 'package:drift/drift.dart';

import 'assets.dart';
import 'tags.dart';

class AssetTags extends Table {
  TextColumn get assetId => text().references(Assets, #id)();
  TextColumn get tagId => text().references(Tags, #id)();

  @override
  Set<Column> get primaryKey => {assetId, tagId};
}
