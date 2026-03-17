import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
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
            const Icon(FluentIcons.color, size: 20),
            const SizedBox(width: 8),
            Text('外观设置', style: theme.typography.subtitle),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ThemeModeSelector(),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 20),
              _AccentColorSelector(),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 20),
              _LocaleSelector(),
              if (PlatformUtils.isDesktop) ...[
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 20),
                _WindowEffectSelector(),
              ],
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 20),
              _AutoSaveChatToggle(),
            ],
          ),
        ),
      ],
    );
  }
}

class _ThemeModeSelector extends ConsumerWidget {
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
            const SizedBox(width: 8),
            ToggleButton(
              checked: themeMode == ThemeMode.light,
              onChanged: (_) =>
                  ref.read(themeNotifierProvider.notifier).setThemeMode(ThemeMode.light),
              child: const Text('亮色'),
            ),
            const SizedBox(width: 8),
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
          spacing: 8,
          runSpacing: 8,
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
                    borderRadius: BorderRadius.circular(6),
                    border: isSelected
                        ? Border.all(
                            color: theme.brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black,
                            width: 2,
                          )
                        : hovered
                            ? Border.all(
                                color: (theme.brightness == Brightness.dark
                                        ? Colors.white
                                        : Colors.black)
                                    .withValues(alpha: 0.5),
                                width: 1.5,
                              )
                            : null,
                  ),
                  child: isSelected
                      ? const Icon(
                          FluentIcons.check_mark,
                          size: 16,
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
            value: locale.toLanguageTag(),
            items: const [
              ComboBoxItem(value: 'zh-CN', child: Text('简体中文')),
              ComboBoxItem(value: 'en', child: Text('English')),
            ],
            onChanged: (tag) {
              if (tag == null) return;
              final parts = tag.split('-');
              final newLocale = parts.length > 1
                  ? Locale(parts[0], parts[1])
                  : Locale(parts[0]);
              ref.read(localeProvider.notifier).setLocale(newLocale);
            },
            isExpanded: true,
          ),
        ),
      ],
    );
  }
}

class _WindowEffectSelector extends ConsumerWidget {
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
        const SizedBox(height: 4),
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
          spacing: 8,
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
