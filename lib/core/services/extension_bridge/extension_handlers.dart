import 'dart:async';
import 'dart:convert';

import 'package:logger/logger.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import '../../database/app_database.dart';
import '../storage/asset_file_manager.dart';

const _appVersion = '1.0.5';
const _jsonHeaders = {'Content-Type': 'application/json'};

class ExtensionHandlers {
  final ProjectDao _projectDao;
  final AssetDao _assetDao;
  final TagDao _tagDao;
  final AssetFileManager _fileManager;

  final StreamController<Asset> importEventController;

  DateTime? _lastHealthPing;
  DateTime? get lastHealthPing => _lastHealthPing;

  static final _log = Logger(printer: PrettyPrinter(methodCount: 0));
  static const _uuid = Uuid();

  ExtensionHandlers({
    required ProjectDao projectDao,
    required AssetDao assetDao,
    required TagDao tagDao,
    required AssetFileManager fileManager,
    required this.importEventController,
  }) : _projectDao = projectDao,
       _assetDao = assetDao,
       _tagDao = tagDao,
       _fileManager = fileManager;

  Router get router {
    final r = Router()
      ..get('/api/health', _health)
      ..get('/api/projects', _listProjects)
      ..post('/api/assets/import-from-extension', _importSingle)
      ..post('/api/assets/batch-import', _batchImport);
    return r;
  }

  Future<Response> _health(Request request) async {
    _lastHealthPing = DateTime.now();
    final body = jsonEncode({
      'status': 'ok',
      'version': _appVersion,
      'app': 'AIO Studio',
    });
    return Response.ok(body, headers: _jsonHeaders);
  }

  Future<Response> _listProjects(Request request) async {
    try {
      final projects = await _projectDao.getAllProjects();
      final active = projects.where((p) => !p.isArchived).toList();

      final list = <Map<String, dynamic>>[];
      for (final project in active) {
        final count = await _assetDao.countByProject(project.id);
        list.add({'id': project.id, 'name': project.name, 'assetCount': count});
      }
      return Response.ok(jsonEncode(list), headers: _jsonHeaders);
    } catch (e, st) {
      _log.e('Failed to list projects', error: e, stackTrace: st);
      return _errorResponse(500, 'Failed to list projects: $e');
    }
  }

  Future<Response> _importSingle(Request request) async {
    try {
      final bodyStr = await request.readAsString();
      final data = jsonDecode(bodyStr) as Map<String, dynamic>;
      final asset = await _importOneAsset(data);
      return Response.ok(
        jsonEncode({'success': true, 'assetId': asset.id}),
        headers: _jsonHeaders,
      );
    } on FormatException catch (e) {
      return _errorResponse(400, 'Invalid JSON: $e');
    } catch (e, st) {
      _log.e('Import failed', error: e, stackTrace: st);
      return _errorResponse(500, 'Import failed: $e');
    }
  }

  Future<Response> _batchImport(Request request) async {
    try {
      final bodyStr = await request.readAsString();
      final items = jsonDecode(bodyStr) as List<dynamic>;
      final results = <Map<String, dynamic>>[];

      final tagCache = await _buildTagCache();

      for (final item in items) {
        try {
          final data = item as Map<String, dynamic>;
          final asset = await _importOneAsset(data, tagCache: tagCache);
          results.add({'success': true, 'assetId': asset.id});
        } catch (e) {
          results.add({'success': false, 'error': '$e'});
        }
      }
      return Response.ok(jsonEncode(results), headers: _jsonHeaders);
    } on FormatException catch (e) {
      return _errorResponse(400, 'Invalid JSON: $e');
    } catch (e, st) {
      _log.e('Batch import failed', error: e, stackTrace: st);
      return _errorResponse(500, 'Batch import failed: $e');
    }
  }

  /// Shared logic for importing a single asset from extension payload.
  Future<Asset> _importOneAsset(
    Map<String, dynamic> data, {
    Map<String, String>? tagCache,
  }) async {
    final mediaUrl = data['mediaUrl'] as String?;
    final mediaBase64 = data['mediaBase64'] as String?;
    final mediaType = (data['mediaType'] as String?) ?? 'image';
    final fileName = (data['fileName'] as String?) ?? 'untitled';
    final projectId = data['projectId'] as String?;
    final name = data['name'] as String?;
    final pageUrl = data['pageUrl'] as String?;
    final pageTitle = data['pageTitle'] as String?;
    final rawTags = data['tags'] as List<dynamic>?;
    final tags = rawTags?.cast<String>();

    final asset = await _fileManager.importFromExtension(
      mediaUrl: mediaUrl,
      mediaBase64: mediaBase64,
      mediaType: mediaType,
      fileName: fileName,
      projectId: projectId,
      name: name,
      pageUrl: pageUrl,
      pageTitle: pageTitle,
    );

    if (tags != null && tags.isNotEmpty) {
      try {
        await _associateTags(asset.id, tags, tagCache: tagCache);
      } catch (e, st) {
        _log.w(
          'Tag association failed for asset ${asset.id}, '
          'asset was imported successfully without tags',
          error: e,
          stackTrace: st,
        );
      }
    }

    importEventController.add(asset);
    return asset;
  }

  Future<Map<String, String>> _buildTagCache() async {
    final existingTags = await _tagDao.getAllTags();
    return {for (final t in existingTags) t.name: t.id};
  }

  /// Creates tags if they don't exist yet and links them to the asset.
  /// When [tagCache] is provided it is used (and updated) instead of
  /// querying the database for every call.
  Future<void> _associateTags(
    String assetId,
    List<String> tagNames, {
    Map<String, String>? tagCache,
  }) async {
    final tagMap = tagCache ?? await _buildTagCache();
    final tagIdsToLink = <String>[];

    for (final name in tagNames) {
      if (tagMap.containsKey(name)) {
        tagIdsToLink.add(tagMap[name]!);
      } else {
        final newTag = TagsCompanion.insert(
          id: _uuid.v4(),
          name: name,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        );
        await _tagDao.insertTag(newTag);
        final tagId = newTag.id.value;
        tagMap[name] = tagId;
        tagIdsToLink.add(tagId);
      }
    }

    if (tagIdsToLink.isNotEmpty) {
      await _tagDao.batchAddTagsToAsset(assetId, tagIdsToLink);
    }
  }

  Response _errorResponse(int statusCode, String message) {
    return Response(
      statusCode,
      body: jsonEncode({'success': false, 'error': message}),
      headers: _jsonHeaders,
    );
  }
}
