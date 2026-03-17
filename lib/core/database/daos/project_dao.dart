import 'package:drift/drift.dart';

import '../../utils/query_utils.dart';
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

  Future<List<Project>> searchByName(
    String query, {
    bool archivedOnly = false,
  }) =>
      (select(projects)
            ..where((t) =>
                likeEscaped(t.name, query) &
                t.isArchived.equals(archivedOnly))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .get();

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
