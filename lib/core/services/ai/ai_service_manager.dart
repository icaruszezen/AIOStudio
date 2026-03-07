import 'dart:convert';

import 'package:logger/logger.dart';

import '../../database/app_database.dart';
import 'ai_models.dart';
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

  void disposeAll() {
    for (final service in _services.values) {
      service.dispose();
    }
    _services.clear();
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
        final modelInfos = _parseModelInfos(extra, cfg.defaultModel);
        return CustomService(
          providerId: cfg.id,
          providerName: cfg.name,
          baseUrl: baseUrl,
          apiKey: apiKey.isNotEmpty ? apiKey : null,
          modelInfos: modelInfos,
        );
      default:
        _log.w('[AiServiceManager] Unknown provider type: ${cfg.type}');
        return null;
    }
  }

  /// All model infos available for the given capability type, with metadata.
  List<AiModelInfo> getAvailableModelInfos(String type) {
    final infos = <AiModelInfo>[];
    for (final s in _services.values) {
      if (s is CustomService) {
        for (final m in s.modelInfos) {
          if (!m.isEnabled) continue;
          final matches = switch (type) {
            'chat' => m.isChatModel,
            'image' => m.isImageModel,
            _ => false,
          };
          if (matches) infos.add(m);
        }
      } else {
        final matches = switch (type) {
          'chat' => s.supportsChatCompletion,
          'image' => s.supportsImageGeneration,
          'video' => s.supportsVideoGeneration,
          _ => false,
        };
        if (matches) {
          final models = type == 'image' ? s.imageModels : s.supportedModels;
          for (final id in models) {
            infos.add(AiModelInfo(id: id));
          }
        }
      }
    }
    return infos;
  }

  // ---------------------------------------------------------------------------
  // Parsing helpers
  // ---------------------------------------------------------------------------

  /// Parses model infos from extraConfig, supporting both new
  /// `discovered_models` format and legacy `models` string-list format.
  static List<AiModelInfo> _parseModelInfos(
      Map<String, dynamic> extra, String? defaultModel) {
    // New format: discovered_models
    final discovered = extra['discovered_models'] as List<dynamic>?;
    if (discovered != null && discovered.isNotEmpty) {
      return discovered
          .map((e) => AiModelInfo.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    // Legacy format: models string list + chat_enabled/image_enabled flags
    final legacyModels = (extra['models'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList();
    if (legacyModels != null && legacyModels.isNotEmpty) {
      final chatEnabled = extra['chat_enabled'] as bool? ?? true;
      final imageEnabled = extra['image_enabled'] as bool? ?? false;
      return legacyModels.map((id) {
        return AiModelInfo(
          id: id,
          mode: imageEnabled && !chatEnabled ? 'image_generation' : 'chat',
        );
      }).toList();
    }

    // Fallback: single default model
    return [AiModelInfo(id: defaultModel ?? 'default')];
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
