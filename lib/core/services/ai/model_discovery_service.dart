import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import 'ai_models.dart';
import 'model_capability_registry.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

/// Fetches the model list from an OpenAI-compatible `/v1/models` endpoint and
/// enriches each entry with capability metadata from [ModelCapabilityRegistry].
class ModelDiscoveryService {
  final ModelCapabilityRegistry _registry;

  ModelDiscoveryService({required ModelCapabilityRegistry registry})
      : _registry = registry;

  /// Calls `GET {baseUrl}/v1/models` and returns enriched [AiModelInfo] items.
  ///
  /// Models are sorted alphabetically. On any HTTP or parsing error the
  /// returned future completes with an exception.
  Future<List<AiModelInfo>> fetchModels({
    required String baseUrl,
    String? apiKey,
  }) async {
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        if (apiKey != null && apiKey.isNotEmpty)
          'Authorization': 'Bearer $apiKey',
      },
    ));

    try {
      final resp = await dio.get<Map<String, dynamic>>('/v1/models');
      final data = resp.data;
      if (data == null) {
        throw Exception('Empty response from /v1/models');
      }

      final rawList = data['data'] as List<dynamic>? ?? [];
      final modelIds = <String>[];

      for (final item in rawList) {
        if (item is Map<String, dynamic>) {
          final id = item['id'] as String?;
          if (id != null && id.isNotEmpty) modelIds.add(id);
        }
      }

      modelIds.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      _log.i('[ModelDiscovery] Fetched ${modelIds.length} models from $baseUrl');

      if (!_registry.isLoaded) await _registry.load();
      return _registry.enrichModels(modelIds);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final msg = e.message ?? e.toString();
      throw Exception('Failed to fetch models (HTTP $status): $msg');
    } finally {
      dio.close();
    }
  }
}
