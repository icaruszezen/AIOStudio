import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/platform_utils.dart';
import '../providers/settings_provider.dart';

class AppearanceSection extends ConsumerWidget {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(FluentIcons.color, size: DesignTokens.iconLG),
            const SizedBox(width: DesignTokens.spacingSM),
            Text('外观设置', style: theme.typography.subtitle),
          ],
        ),
        const SizedBox(height: DesignTokens.spacingMD),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ThemeModeSelector(),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 20),
              const _AccentColorSelector(),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 20),
              const _LocaleSelector(),
              if (PlatformUtils.isDesktop) ...[
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 20),
                const _WindowEffectSelector(),
              ],
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 20),
              const _AutoSaveChatToggle(),
            ],
          ),
        ),
      ],
    );
  }
}

class _ThemeModeSelector extends ConsumerWidget {
  const _ThemeModeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final themeMode = ref.watch(themeNotifierProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('主题模式', style: theme.typography.bodyStrong),
        const SizedBox(height: 10),
        Row(
          children: [
            ToggleButton(
              checked: themeMode == ThemeMode.system,
              onChanged: (_) =>
                  ref.read(themeNotifierProvider.notifier).setThemeMode(ThemeMode.system),
              child: const Text('跟随系统'),
            ),
            const SizedBox(width: DesignTokens.spacingSM),
            ToggleButton(
              checked: themeMode == ThemeMode.light,
              onChanged: (_) =>
                  ref.read(themeNotifierProvider.notifier).setThemeMode(ThemeMode.light),
              child: const Text('亮色'),
            ),
            const SizedBox(width: DesignTokens.spacingSM),
            ToggleButton(
              checked: themeMode == ThemeMode.dark,
              onChanged: (_) =>
                  ref.read(themeNotifierProvider.notifier).setThemeMode(ThemeMode.dark),
              child: const Text('暗色'),
            ),
          ],
        ),
      ],
    );
  }
}

class _AccentColorSelector extends ConsumerWidget {
  const _AccentColorSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final current = ref.watch(accentColorProvider);
    final colors = availableAccentColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('强调色', style: theme.typography.bodyStrong),
        const SizedBox(height: 10),
        Wrap(
          spacing: DesignTokens.spacingSM,
          runSpacing: DesignTokens.spacingSM,
          children: colors.map((color) {
            final isSelected = color == current;
            return HoverButton(
              onPressed: () =>
                  ref.read(accentColorProvider.notifier).setAccentColor(color),
              builder: (context, states) {
                final hovered = states.isHovered;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                    border: isSelected
                        ? Border.all(
                            color: AppColors.selectionBorder(theme.brightness),
                            width: 2,
                          )
                        : hovered
                            ? Border.all(
                                color: AppColors.selectionBorderSubtle(
                                  theme.brightness,
                                ),
                                width: 1.5,
                              )
                            : null,
                  ),
                  child: isSelected
                      ? const Icon(
                          FluentIcons.check_mark,
                          size: DesignTokens.iconMD,
                          color: AppColors.onAccent,
                        )
                      : null,
                );
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _LocaleSelector extends ConsumerWidget {
  const _LocaleSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final locale = ref.watch(localeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('界面语言', style: theme.typography.bodyStrong),
        const SizedBox(height: 10),
        SizedBox(
          width: 200,
          child: ComboBox<String>(
            value: locale.languageCode,
            items: const [
              ComboBoxItem(value: 'zh', child: Text('简体中文')),
              ComboBoxItem(value: 'en', child: Text('English')),
            ],
            onChanged: (code) {
              if (code == null) return;
              ref.read(localeProvider.notifier).setLocale(Locale(code));
            },
            isExpanded: true,
          ),
        ),
      ],
    );
  }
}

class _WindowEffectSelector extends ConsumerWidget {
  const _WindowEffectSelector();

  static const _effectLabels = <AppWindowEffect, String>{
    AppWindowEffect.none: '无',
    AppWindowEffect.acrylic: 'Acrylic',
    AppWindowEffect.mica: 'Mica',
    AppWindowEffect.tabbed: 'Tabbed',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final current = ref.watch(windowEffectProvider);
    final isWindows = defaultTargetPlatform == TargetPlatform.windows;

    final effects = isWindows
        ? AppWindowEffect.values
        : [AppWindowEffect.none, AppWindowEffect.acrylic];

    final effectiveCurrent = effects.contains(current)
        ? current
        : (current == AppWindowEffect.mica || current == AppWindowEffect.tabbed)
            ? AppWindowEffect.acrylic
            : AppWindowEffect.none;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('窗口效果', style: theme.typography.bodyStrong),
        const SizedBox(height: DesignTokens.spacingXS),
        Text(
          isWindows
              ? 'Acrylic 半透明模糊，Mica 基于壁纸取色，Tabbed 基于 Mica 增强'
              : '仅 Acrylic（半透明模糊）在此平台可用',
          style: theme.typography.caption?.copyWith(
            color: theme.resources.textFillColorSecondary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: DesignTokens.spacingSM,
          children: [
            for (final effect in effects)
              ToggleButton(
                checked: effectiveCurrent == effect,
                onChanged: (_) => ref
                    .read(windowEffectProvider.notifier)
                    .setEffect(effect),
                child: Text(_effectLabels[effect] ?? effect.name),
              ),
          ],
        ),
      ],
    );
  }
}

class _AutoSaveChatToggle extends ConsumerWidget {
  const _AutoSaveChatToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final autoSave = ref.watch(autoSaveChatProvider);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('自动保存聊天记录', style: theme.typography.bodyStrong),
              const SizedBox(height: 2),
              Text(
                '开启后，对话内容会自动保存到本地',
                style: theme.typography.caption?.copyWith(
                  color: theme.resources.textFillColorSecondary,
                ),
              ),
            ],
          ),
        ),
        ToggleSwitch(
          checked: autoSave,
          onChanged: (_) => ref.read(autoSaveChatProvider.notifier).toggle(),
        ),
      ],
    );
  }
}
