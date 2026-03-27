import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/ai_providers.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/services/ai/provider_presets.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/error_utils.dart';
import '../views/ai_provider_dialog.dart';

final _allProvidersProvider =
    StreamProvider.autoDispose<List<AiProviderConfig>>((ref) {
      return ref.watch(aiProviderConfigDaoProvider).watchAll();
    });

class AiProvidersSection extends ConsumerWidget {
  const AiProvidersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final providersAsync = ref.watch(_allProvidersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(FluentIcons.cloud, size: 20),
            const SizedBox(width: 8),
            Text('AI 服务商管理', style: theme.typography.subtitle),
            const Spacer(),
            FilledButton(
              onPressed: () => _addProvider(context, ref),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.add, size: 12),
                  SizedBox(width: 6),
                  Text('添加服务商'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        providersAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: ProgressRing()),
          ),
          error: (e, _) => InfoBar(
            title: const Text('加载失败'),
            content: Text(formatUserError(e)),
            severity: InfoBarSeverity.error,
          ),
          data: (providers) {
            if (providers.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          FluentIcons.cloud_not_synced,
                          size: 32,
                          color: theme.resources.textFillColorSecondary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '尚未配置任何 AI 服务商',
                          style: theme.typography.body?.copyWith(
                            color: theme.resources.textFillColorSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Button(
                          onPressed: () => _addProvider(context, ref),
                          child: const Text('添加服务商'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            return Card(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < providers.length; i++) ...[
                    _ProviderRow(config: providers[i]),
                    if (i < providers.length - 1) const Divider(),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  void _addProvider(BuildContext context, WidgetRef ref) {
    AiProviderDialog.show(context).then((saved) {
      if (saved == true) {
        reloadAiServices(ref);
      }
    });
  }
}

class _ProviderRow extends ConsumerStatefulWidget {
  const _ProviderRow({required this.config});

  final AiProviderConfig config;

  @override
  ConsumerState<_ProviderRow> createState() => _ProviderRowState();
}

class _ProviderRowState extends ConsumerState<_ProviderRow> {
  final _flyoutController = FlyoutController();

  AiProviderConfig get config => widget.config;

  @override
  void dispose() {
    _flyoutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final presetId = ProviderPresets.resolvePresetId(
      config.type,
      config.baseUrl,
      config.extraConfig,
    );
    final preset = ProviderPresets.getById(presetId);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _providerIcon(preset, theme),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(config.name, style: theme.typography.bodyStrong),
                const SizedBox(height: 2),
                Row(
                  children: [
                    _TypeBadge(preset: preset, fallbackType: config.type),
                    const SizedBox(width: 8),
                    _StatusIndicator(config: config, preset: preset),
                  ],
                ),
              ],
            ),
          ),
          ToggleSwitch(checked: config.isEnabled, onChanged: _toggleEnabled),
          const SizedBox(width: 8),
          _buildActions(theme),
        ],
      ),
    );
  }

  Widget _buildActions(FluentThemeData theme) {
    final errorColor = AppColors.error(theme.brightness);
    return FlyoutTarget(
      controller: _flyoutController,
      child: IconButton(
        icon: const Icon(FluentIcons.more, size: 16),
        onPressed: () {
          _flyoutController.showFlyout(
            barrierDismissible: true,
            dismissOnPointerMoveAway: false,
            builder: (ctx) => MenuFlyout(
              items: [
                MenuFlyoutItem(
                  leading: const Icon(FluentIcons.edit),
                  text: const Text('编辑'),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _editProvider();
                  },
                ),
                MenuFlyoutItem(
                  leading: const Icon(FluentIcons.plug_connected),
                  text: const Text('测试连接'),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _testConnection();
                  },
                ),
                const MenuFlyoutSeparator(),
                MenuFlyoutItem(
                  leading: Icon(FluentIcons.delete, color: errorColor),
                  text: Text('删除', style: TextStyle(color: errorColor)),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _deleteProvider();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _toggleEnabled(bool value) async {
    final dao = ref.read(aiProviderConfigDaoProvider);
    await dao.updateEnabled(config.id, value);
    reloadAiServices(ref);
  }

  void _editProvider() {
    AiProviderDialog.show(context, existing: config).then((saved) {
      if (saved == true) {
        reloadAiServices(ref);
      }
    });
  }

  Future<void> _testConnection() async {
    try {
      final manager = await ref.read(aiServicesReadyProvider.future);
      final service = manager.getService(config.id);
      if (service == null) {
        if (mounted) {
          displayInfoBar(
            context,
            builder: (ctx, close) => InfoBar(
              title: const Text('测试失败'),
              content: const Text('服务未加载，请检查配置并确保已启用'),
              severity: InfoBarSeverity.error,
              onClose: close,
            ),
          );
        }
        return;
      }
      await service.testConnection();
      if (mounted) {
        displayInfoBar(
          context,
          builder: (ctx, close) => InfoBar(
            title: const Text('连接成功'),
            content: Text('${config.name} 连接正常'),
            severity: InfoBarSeverity.success,
            onClose: close,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        displayInfoBar(
          context,
          builder: (ctx, close) => InfoBar(
            title: const Text('连接失败'),
            content: Text(formatUserError(e)),
            severity: InfoBarSeverity.error,
            onClose: close,
          ),
        );
      }
    }
  }

  Future<void> _deleteProvider() async {
    final taskCount = await ref
        .read(aiTaskDaoProvider)
        .countByProvider(config.id);

    if (!mounted) return;
    final errorColor = AppColors.error(FluentTheme.of(context).brightness);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('确认删除'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('确定要删除服务商 "${config.name}" 吗？此操作不可撤销。'),
            if (taskCount > 0) ...[
              const SizedBox(height: 8),
              InfoBar(
                title: Text('该服务商关联了 $taskCount 条 AI 任务记录'),
                content: const Text('删除后相关任务记录仍会保留，但无法再使用此服务商。'),
                severity: InfoBarSeverity.warning,
              ),
            ],
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(errorColor),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final dao = ref.read(aiProviderConfigDaoProvider);
      final secureKeys = ref.read(secureKeyServiceProvider);
      await secureKeys.deleteApiKey(config.id);
      await dao.deleteConfig(config.id);
      reloadAiServices(ref);
    }
  }

  static Widget _providerIcon(ProviderPreset? preset, FluentThemeData theme) {
    final icon = preset?.icon ?? FluentIcons.cloud;
    final color =
        preset?.color(theme.brightness) ?? AppColors.pending(theme.brightness);

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.preset, required this.fallbackType});
  final ProviderPreset? preset;
  final String fallbackType;

  @override
  Widget build(BuildContext context) {
    final label = preset?.name ?? fallbackType;
    final theme = FluentTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: theme.resources.subtleFillColorSecondary,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: theme.typography.caption),
    );
  }
}

final _hasSecureApiKeyProvider = FutureProvider.autoDispose
    .family<bool, String>((ref, providerId) {
      return ref.watch(secureKeyServiceProvider).hasApiKey(providerId);
    });

class _StatusIndicator extends ConsumerWidget {
  const _StatusIndicator({required this.config, required this.preset});
  final AiProviderConfig config;
  final ProviderPreset? preset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final b = theme.brightness;
    final secureKeyAsync = ref.watch(_hasSecureApiKeyProvider(config.id));
    final hasApiKey = secureKeyAsync.value ?? false;
    final hasBaseUrl = config.baseUrl != null && config.baseUrl!.isNotEmpty;
    final requiresBaseUrl = config.type == 'custom';
    final configured =
        (!requiresBaseUrl || hasBaseUrl) &&
        (!(preset?.requiresApiKey ?? false) || hasApiKey);
    final color = configured ? AppColors.success(b) : AppColors.warning(b);
    final label = switch ((
      configured,
      hasBaseUrl,
      preset?.requiresApiKey ?? false,
    )) {
      (true, _, _) => '已配置',
      (false, false, _) when requiresBaseUrl => '缺少地址',
      (false, _, true) => '缺少 API Key',
      _ => '未配置',
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: theme.typography.caption?.copyWith(color: color)),
      ],
    );
  }
}
