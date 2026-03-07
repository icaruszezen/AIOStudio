import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

import 'ai_models.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

/// Loads and queries a bundled model-capability registry (derived from LiteLLM)
/// so the app can auto-populate modality / context-window info for discovered
/// model IDs.
class ModelCapabilityRegistry {
  Map<String, Map<String, dynamic>> _data = {};
  bool _loaded = false;

  static const _assetPath = 'assets/model_capabilities.json';
  static const _remoteUrl =
      'https://raw.githubusercontent.com/BerriAI/litellm/main/'
      'model_prices_and_context_window.json';

  bool get isLoaded => _loaded;

  /// Load the bundled asset JSON into memory.
  Future<void> load() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      _data = parsed.map((k, v) =>
          MapEntry(k.toLowerCase(), v as Map<String, dynamic>));
      _loaded = true;
      _log.i('[ModelRegistry] Loaded ${_data.length} model entries');
    } catch (e) {
      _log.e('[ModelRegistry] Failed to load asset: $e');
    }
  }

  /// Look up capability data for [modelId].
  ///
  /// Matching strategy (first match wins):
  /// 1. Exact match
  /// 2. Strip common provider prefixes (e.g. `openai/gpt-4o` -> `gpt-4o`)
  /// 3. Strip date suffixes (e.g. `gpt-4o-2024-08-06` -> `gpt-4o`)
  /// 4. Longest-prefix match among registry keys
  AiModelInfo? lookup(String modelId) {
    final key = modelId.toLowerCase().trim();
    if (key.isEmpty) return null;

    // 1. Exact match
    final exact = _data[key];
    if (exact != null) return AiModelInfo.fromCapability(modelId, exact);

    // 2. Strip provider prefix  (e.g. "openai/gpt-4o" -> "gpt-4o")
    final stripped = _stripProviderPrefix(key);
    if (stripped != key) {
      final match = _data[stripped];
      if (match != null) return AiModelInfo.fromCapability(modelId, match);
    }

    // 3. Strip date suffix (e.g. "gpt-4o-2024-08-06" -> "gpt-4o")
    final noDate = _stripDateSuffix(stripped);
    if (noDate != stripped) {
      final match = _data[noDate];
      if (match != null) return AiModelInfo.fromCapability(modelId, match);
    }

    // 4. Longest registry-key prefix that matches
    String? bestKey;
    for (final rk in _data.keys) {
      if (stripped.startsWith(rk) &&
          (bestKey == null || rk.length > bestKey.length)) {
        bestKey = rk;
      }
    }
    if (bestKey != null) {
      return AiModelInfo.fromCapability(modelId, _data[bestKey]!);
    }

    return null;
  }

  /// Enrich a list of bare model IDs into [AiModelInfo] objects.
  List<AiModelInfo> enrichModels(List<String> modelIds) {
    return modelIds.map((id) {
      return lookup(id) ?? AiModelInfo(id: id);
    }).toList();
  }

  /// Optionally refresh from the remote LiteLLM JSON on GitHub.
  ///
  /// Only extracts the fields we care about to keep memory small.
  Future<bool> updateFromRemote() async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
      ));
      final resp = await dio.get<String>(_remoteUrl);
      if (resp.statusCode != 200 || resp.data == null) return false;

      final parsed = jsonDecode(resp.data!) as Map<String, dynamic>;
      final curated = <String, Map<String, dynamic>>{};

      for (final entry in parsed.entries) {
        if (entry.key == 'sample_spec') continue;
        final v = entry.value;
        if (v is! Map<String, dynamic>) continue;
        final mode = v['mode'] as String?;
        if (mode == null) continue;

        curated[entry.key.toLowerCase()] = {
          if (v['max_input_tokens'] != null)
            'max_input_tokens': v['max_input_tokens'],
          if (v['max_output_tokens'] != null)
            'max_output_tokens': v['max_output_tokens'],
          'mode': mode,
          if (v['supports_vision'] == true) 'supports_vision': true,
          if (v['supports_function_calling'] == true)
            'supports_function_calling': true,
          if (v['supports_reasoning'] == true) 'supports_reasoning': true,
          if (v['supported_modalities'] != null)
            'supported_modalities': v['supported_modalities'],
          if (v['supported_output_modalities'] != null)
            'supported_output_modalities': v['supported_output_modalities'],
        };
      }

      _data = curated;
      _loaded = true;
      _log.i('[ModelRegistry] Remote update: ${_data.length} entries');
      return true;
    } catch (e) {
      _log.w('[ModelRegistry] Remote update failed: $e');
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  static String _stripProviderPrefix(String key) {
    final idx = key.indexOf('/');
    return idx > 0 ? key.substring(idx + 1) : key;
  }

  static final _dateSuffixRe = RegExp(r'-\d{4}[-/]\d{2}[-/]\d{2}$');
  static final _versionSuffixRe = RegExp(r'-\d{6,}$');

  static String _stripDateSuffix(String key) {
    var result = key.replaceFirst(_dateSuffixRe, '');
    if (result == key) {
      result = key.replaceFirst(_versionSuffixRe, '');
    }
    return result;
  }
}
