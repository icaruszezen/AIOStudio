import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ai/ai_service.dart';
import '../services/ai/ai_service_manager.dart';
import 'database_provider.dart';

final aiServiceManagerProvider = Provider<AiServiceManager>((ref) {
  final manager = AiServiceManager(
    dao: ref.watch(aiProviderConfigDaoProvider),
  );
  ref.onDispose(manager.disposeAll);
  return manager;
});

/// Triggers [AiServiceManager.loadServices] and exposes the ready manager.
///
/// UI code should `await ref.watch(aiServicesReadyProvider.future)` before
/// calling any AI service.
final aiServicesReadyProvider = FutureProvider<AiServiceManager>((ref) async {
  final manager = ref.watch(aiServiceManagerProvider);
  await manager.loadServices();
  return manager;
});

/// Available model identifiers for the given capability type
/// ("chat", "image", "video").
final availableModelsProvider =
    FutureProvider.family<List<String>, String>((ref, type) async {
  final manager = await ref.watch(aiServicesReadyProvider.future);
  return manager.getAvailableModels(type);
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
