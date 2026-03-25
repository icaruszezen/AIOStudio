import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/ai_providers.dart';
import '../providers/chat_provider.dart';

class ModelSelector extends ConsumerWidget {
  const ModelSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedProviderId = ref.watch(
      chatProvider.select((s) => s.selectedProviderId),
    );
    final selectedModel = ref.watch(
      chatProvider.select((s) => s.selectedModel),
    );
    final isLoading = ref.watch(
      aiServicesReadyProvider.select((s) => s.isLoading),
    );
    final notifier = ref.read(chatProvider.notifier);

    if (isLoading) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: ProgressRing(strokeWidth: 2),
      );
    }

    final groups = notifier.getAvailableModelGroups();

    if (groups.isEmpty) {
      return const _EmptySelector();
    }

    final currentKey = (selectedProviderId != null && selectedModel != null)
        ? '$selectedProviderId::$selectedModel'
        : null;

    final items = <ComboBoxItem<String>>[];
    for (final group in groups) {
      // Group header (non-selectable)
      items.add(ComboBoxItem<String>(
        value: '__header__${group.providerId}',
        enabled: false,
        child: Text(
          group.providerName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ));
      for (final model in group.models) {
        final key = '${group.providerId}::$model';
        items.add(ComboBoxItem<String>(
          value: key,
          child: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(model, style: const TextStyle(fontSize: 13)),
          ),
        ));
      }
    }

    // Ensure current value exists in items
    final validKeys =
        items.map((i) => i.value).where((v) => v != null).toSet();
    final effectiveValue =
        (currentKey != null && validKeys.contains(currentKey))
            ? currentKey
            : null;

    return ComboBox<String>(
      value: effectiveValue,
      items: items,
      onChanged: (value) {
        if (value == null || value.startsWith('__header__')) return;
        final parts = value.split('::');
        if (parts.length == 2) {
          notifier.selectModel(parts[0], parts[1]);
        }
      },
      placeholder: const Text('选择模型'),
    );
  }
}

class _EmptySelector extends StatelessWidget {
  const _EmptySelector();

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          FluentIcons.warning,
          size: 14,
          color: theme.resources.textFillColorSecondary,
        ),
        const SizedBox(width: 6),
        Text(
          '未配置 AI 服务',
          style: theme.typography.caption?.copyWith(
            color: theme.resources.textFillColorSecondary,
          ),
        ),
      ],
    );
  }
}
