import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
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
            return GestureDetector(
              onTap: () =>
                  ref.read(accentColorProvider.notifier).setAccentColor(color),
              child: Container(
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
                      : null,
                ),
                child: isSelected
                    ? const Icon(
                        FluentIcons.check_mark,
                        size: 16,
                        color: AppColors.onAccent,
                      )
                    : null,
              ),
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
