import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/projects.dart';

part 'project_dao.g.dart';

@DriftAccessor(tables: [Projects])
class ProjectDao extends DatabaseAccessor<AppDatabase>
    with _$ProjectDaoMixin {
  ProjectDao(super.db);

  Future<List<Project>> getAllProjects() => select(projects).get();

  Stream<List<Project>> watchAllProjects() => select(projects).watch();

  Future<Project?> getProjectById(String id) =>
      (select(projects)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertProject(ProjectsCompanion entry) =>
      into(projects).insert(entry);

  Future<bool> updateProject(ProjectsCompanion entry) =>
      update(projects).replace(entry);

  Future<int> deleteProject(String id) =>
      (delete(projects)..where((t) => t.id.equals(id))).go();

  Future<void> toggleArchive(String id, {required bool archived}) =>
      (update(projects)..where((t) => t.id.equals(id))).write(
        ProjectsCompanion(isArchived: Value(archived)),
      );

  Future<List<Project>> searchByName(String query) async {
    final escaped = query
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    final rows = await customSelect(
      'SELECT * FROM projects WHERE name LIKE ? ESCAPE ?',
      variables: [
        Variable.withString('%$escaped%'),
        Variable.withString(r'\'),
      ],
      readsFrom: {projects},
    ).get();
    return rows.map((row) => projects.map(row.data)).toList();
  }

  Stream<List<Project>> watchActiveProjects() => (select(projects)
        ..where((t) => t.isArchived.equals(false))
        ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
      .watch();

  Stream<List<Project>> watchArchivedProjects() => (select(projects)
        ..where((t) => t.isArchived.equals(true))
        ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
      .watch();

  Stream<Project?> watchProjectById(String id) =>
      (select(projects)..where((t) => t.id.equals(id)))
          .watchSingleOrNull();
}
