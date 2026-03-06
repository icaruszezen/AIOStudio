import 'dart:convert';

import 'package:logger/logger.dart';

import '../../database/app_database.dart';
import '../../database/daos/ai_provider_config_dao.dart';
import 'ai_service.dart';
import 'anthropic_service.dart';
import 'custom_service.dart';
import 'openai_service.dart';
import 'stability_service.dart';

/// Central registry that instantiates [AiService] implementations from
/// persisted [AiProviderConfig] rows.
class AiServiceManager {
  final AiProviderConfigDao _dao;
  final Map<String, AiService> _services = {};

  static final _log = Logger(printer: PrettyPrinter(methodCount: 0));

  AiServiceManager({required AiProviderConfigDao dao}) : _dao = dao;

  /// Reads all enabled provider configs from the database and creates the
  /// corresponding service instances.  Safe to call multiple times – disposes
  /// and clears previous instances first.
  Future<void> loadServices() async {
    for (final service in _services.values) {
      service.dispose();
    }
    _services.clear();
    final configs = await _dao.getEnabled();

    for (final cfg in configs) {
      try {
        final service = _createService(cfg);
        if (service != null) {
          _services[cfg.id] = service;
          _log.i('[AiServiceManager] Loaded ${service.providerName} '
              '(${cfg.id})');
        }
      } catch (e) {
        _log.e('[AiServiceManager] Failed to load provider '
            '${cfg.name} (${cfg.id}): $e');
      }
    }
  }

  AiService? getService(String providerId) => _services[providerId];

  AiService? getDefaultChatService() => _services.values
      .where((s) => s.supportsChatCompletion)
      .firstOrNull;

  AiService? getDefaultImageService() => _services.values
      .where((s) => s.supportsImageGeneration)
      .firstOrNull;

  AiService? getDefaultVideoService() => _services.values
      .where((s) => s.supportsVideoGeneration)
      .firstOrNull;

  List<AiService> getAllEnabledServices() =>
      List.unmodifiable(_services.values);

  List<AiService> getImageServices() => _services.values
      .where((s) => s.supportsImageGeneration)
      .toList(growable: false);

  List<AiService> getVideoServices() => _services.values
      .where((s) => s.supportsVideoGeneration)
      .toList(growable: false);

  /// All model identifiers available for the given capability type.
  List<String> getAvailableModels(String type) {
    final services = _services.values.where((s) {
      switch (type) {
        case 'chat':
          return s.supportsChatCompletion;
        case 'image':
          return s.supportsImageGeneration;
        case 'video':
          return s.supportsVideoGeneration;
        default:
          return false;
      }
    });

    return services.expand((s) => s.supportedModels).toList();
  }

  // ---------------------------------------------------------------------------
  // Factory
  // ---------------------------------------------------------------------------

  AiService? _createService(AiProviderConfig cfg) {
    final apiKey = cfg.apiKey ?? '';
    final baseUrl = cfg.baseUrl;
    final extra = _parseExtraConfig(cfg.extraConfig);

    switch (cfg.type) {
      case 'openai':
        return OpenAiService(
          providerId: cfg.id,
          apiKey: apiKey,
          baseUrl: baseUrl ?? 'https://api.openai.com',
        );
      case 'anthropic':
        return AnthropicService(
          providerId: cfg.id,
          apiKey: apiKey,
          baseUrl: baseUrl ?? 'https://api.anthropic.com',
        );
      case 'stability':
        return StabilityService(
          providerId: cfg.id,
          apiKey: apiKey,
          baseUrl: baseUrl ?? 'https://api.stability.ai',
        );
      case 'custom':
        if (baseUrl == null || baseUrl.isEmpty) {
          _log.w('[AiServiceManager] Skipping custom provider '
              '${cfg.name}: missing baseUrl');
          return null;
        }
        final models = (extra['models'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [cfg.defaultModel ?? 'default'];
        return CustomService(
          providerId: cfg.id,
          providerName: cfg.name,
          baseUrl: baseUrl,
          apiKey: apiKey.isNotEmpty ? apiKey : null,
          models: models,
          chatEnabled: extra['chat_enabled'] as bool? ?? true,
          imageEnabled: extra['image_enabled'] as bool? ?? false,
        );
      default:
        _log.w('[AiServiceManager] Unknown provider type: ${cfg.type}');
        return null;
    }
  }

  static Map<String, dynamic> _parseExtraConfig(String? json) {
    if (json == null || json.isEmpty) return {};
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}
