import 'package:drift/drift.dart';

import '../../utils/query_utils.dart';
import '../app_database.dart';
import '../tables/projects.dart';

part 'project_dao.g.dart';

/// Drift DAO for reading and writing project rows in the local database.
@DriftAccessor(tables: [Projects])
class ProjectDao extends DatabaseAccessor<AppDatabase>
    with _$ProjectDaoMixin {
  ProjectDao(super.db);

  /// Returns every project row with no ordering or filtering.
  Future<List<Project>> getAllProjects() => select(projects).get();

  /// Emits the full project list whenever the projects table changes.
  Stream<List<Project>> watchAllProjects() => select(projects).watch();

  /// Returns the project with [id], or null if none exists.
  Future<Project?> getProjectById(String id) =>
      (select(projects)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Inserts [entry] and returns the row id Drift assigns.
  Future<int> insertProject(ProjectsCompanion entry) =>
      into(projects).insert(entry);

  /// Replaces the row matching [entry] and returns whether a row was updated.
  Future<bool> updateProject(ProjectsCompanion entry) =>
      update(projects).replace(entry);

  /// Deletes the project with [id] and returns the number of rows removed.
  Future<int> deleteProject(String id) =>
      (delete(projects)..where((t) => t.id.equals(id))).go();

  /// Sets [archived] on the project identified by [id].
  Future<void> toggleArchive(String id, {required bool archived}) =>
      (update(projects)..where((t) => t.id.equals(id))).write(
        ProjectsCompanion(isArchived: Value(archived)),
      );

  /// Returns projects whose name matches [query], optionally only archived ones, newest first.
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

  /// Emits non-archived projects ordered by [Project.updatedAt] descending.
  Stream<List<Project>> watchActiveProjects() => (select(projects)
        ..where((t) => t.isArchived.equals(false))
        ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
      .watch();

  /// Emits archived projects ordered by [Project.updatedAt] descending.
  Stream<List<Project>> watchArchivedProjects() => (select(projects)
        ..where((t) => t.isArchived.equals(true))
        ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
      .watch();

  /// Emits the project with [id], or null, and updates when that row changes.
  Stream<Project?> watchProjectById(String id) =>
      (select(projects)..where((t) => t.id.equals(id)))
          .watchSingleOrNull();
}
