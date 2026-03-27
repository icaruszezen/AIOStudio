import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ai/ai_models.dart';
import '../services/ai/ai_service.dart';
import '../services/ai/ai_service_manager.dart';
import '../services/ai/model_capability_registry.dart';
import '../services/ai/model_discovery_service.dart';
import 'database_provider.dart';

final modelCapabilityRegistryProvider = Provider<ModelCapabilityRegistry>((
  ref,
) {
  return ModelCapabilityRegistry();
});

final modelDiscoveryServiceProvider = Provider<ModelDiscoveryService>((ref) {
  return ModelDiscoveryService(
    registry: ref.watch(modelCapabilityRegistryProvider),
  );
});

final aiServiceManagerProvider = Provider<AiServiceManager>((ref) {
  final manager = AiServiceManager(
    dao: ref.watch(aiProviderConfigDaoProvider),
    secureKeys: ref.watch(secureKeyServiceProvider),
  );
  ref.onDispose(manager.disposeAll);
  return manager;
});

/// Call from widget code after any AI provider config change to reload all
/// services. Centralises the invalidation so callers don't depend on internal
/// provider topology.
void reloadAiServices(WidgetRef ref) {
  ref.invalidate(aiServicesReadyProvider);
}

/// Triggers [AiServiceManager.loadServices] and exposes the ready manager.
///
/// UI code should `await ref.watch(aiServicesReadyProvider.future)` before
/// calling any AI service. Call [reloadAiServices] after config changes.
final aiServicesReadyProvider = FutureProvider<AiServiceManager>((ref) async {
  final manager = ref.watch(aiServiceManagerProvider);
  await manager.loadServices();
  return manager;
});

/// Available model identifiers for the given capability type
/// ("chat", "image", "video").
final availableModelsProvider = FutureProvider.autoDispose
    .family<List<AiModelInfo>, String>((ref, type) async {
      final manager = await ref.watch(aiServicesReadyProvider.future);
      return manager.getAvailableModelInfos(type);
    });

final defaultChatServiceProvider = Provider<AiService?>((ref) {
  final managerAsync = ref.watch(aiServicesReadyProvider);
  return managerAsync.whenOrNull(data: (m) => m.getDefaultChatService());
});

final defaultImageServiceProvider = Provider<AiService?>((ref) {
  final managerAsync = ref.watch(aiServicesReadyProvider);
  return managerAsync.whenOrNull(data: (m) => m.getDefaultImageService());
});

final defaultVideoServiceProvider = Provider<AiService?>((ref) {
  final managerAsync = ref.watch(aiServicesReadyProvider);
  return managerAsync.whenOrNull(data: (m) => m.getDefaultVideoService());
});
