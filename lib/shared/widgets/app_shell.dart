import 'package:fluent_ui/fluent_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/platform_utils.dart';
import '../../l10n/app_localizations.dart';

/// Root layout shell with navigation pane, title bar, and desktop window controls.
/// Wraps routed content and drives primary section navigation via [go_router].
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _NavItem {
  const _NavItem({required this.route, required this.icon});
  final String route;
  final IconData icon;
}

class _AppShellState extends State<AppShell> with WindowListener {
  static const _topItems = [
    _NavItem(route: AppRoutes.projects, icon: FluentIcons.project_management),
    _NavItem(route: AppRoutes.assets, icon: FluentIcons.photo_collection),
    _NavItem(route: AppRoutes.prompts, icon: FluentIcons.text_document),
  ];

  static const _aiItems = [
    _NavItem(route: AppRoutes.aiChat, icon: FluentIcons.chat),
    _NavItem(route: AppRoutes.aiImage, icon: FluentIcons.image_search),
    _NavItem(route: AppRoutes.aiVideo, icon: FluentIcons.video),
  ];

  static const _footerNavItems = [
    _NavItem(route: AppRoutes.settings, icon: FluentIcons.settings),
  ];

  static final _allSelectableItems = [
    ..._topItems,
    ..._aiItems,
    ..._footerNavItems,
  ];

  static String _navTitle(_NavItem item, S l) {
    return switch (item.route) {
      AppRoutes.projects => l.navProjects,
      AppRoutes.assets => l.navAssets,
      AppRoutes.prompts => l.navPrompts,
      AppRoutes.aiChat => l.navChat,
      AppRoutes.aiImage => l.navImageGen,
      AppRoutes.aiVideo => l.navVideoGen,
      AppRoutes.settings => l.navSettings,
      _ => '',
    };
  }

  bool _isMaximized = false;
  bool _isPaneExpanded = true;

  @override
  void initState() {
    super.initState();
    if (PlatformUtils.isDesktop) {
      windowManager.addListener(this);
      windowManager.isMaximized().then((v) {
        if (mounted) setState(() => _isMaximized = v);
      });
    }
  }

  @override
  void dispose() {
    if (PlatformUtils.isDesktop) windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _isMaximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _isMaximized = false);

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    for (var i = 0; i < _allSelectableItems.length; i++) {
      final route = _allSelectableItems[i].route;
      if (location == route || location.startsWith('$route/')) {
        return i;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);
    final l = S.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth <= Breakpoints.tablet;

        final paneDisplayMode = isNarrow
            ? PaneDisplayMode.minimal
            : (_isPaneExpanded
                  ? PaneDisplayMode.expanded
                  : PaneDisplayMode.compact);

        final paneToggle = PaneToggleButton(
          onPressed: () => setState(() => _isPaneExpanded = !_isPaneExpanded),
        );

        Widget content = NavigationView(
          titleBar: PlatformUtils.isMobile
              ? const SizedBox.shrink()
              : _buildTitleBar(context),
          pane: NavigationPane(
            selected: selectedIndex,
            onChanged: (index) {
              if (index >= 0 && index < _allSelectableItems.length) {
                context.go(_allSelectableItems[index].route);
              }
            },
            displayMode: paneDisplayMode,
            size: const NavigationPaneSize(openWidth: 200),
            toggleButton: paneToggle,
            toggleButtonPosition: PaneToggleButtonPreferredPosition.pane,
            header: _isPaneExpanded ? paneToggle : const SizedBox.shrink(),
            items: [
              for (final item in _topItems)
                PaneItem(
                  icon: Icon(item.icon),
                  title: Text(_navTitle(item, l)),
                  body: const SizedBox.shrink(),
                ),
              PaneItemSeparator(),
              for (final item in _aiItems)
                PaneItem(
                  icon: Icon(item.icon),
                  title: Text(_navTitle(item, l)),
                  body: const SizedBox.shrink(),
                ),
            ],
            footerItems: [
              for (final item in _footerNavItems)
                PaneItem(
                  icon: Icon(item.icon),
                  title: Text(_navTitle(item, l)),
                  body: const SizedBox.shrink(),
                ),
            ],
          ),
          paneBodyBuilder: (item, body) => widget.child,
        );

        if (PlatformUtils.isMobile) {
          content = SafeArea(child: content);
        }

        return content;
      },
    );
  }

  Widget _buildTitleBar(BuildContext context) {
    final theme = FluentTheme.of(context);

    final titleContent = SizedBox(
      height: 32,
      child: Row(
        children: [
          const SizedBox(width: 12),
          Image.asset('assets/logo.png', width: 16, height: 16),
          const SizedBox(width: 8),
          Text(
            'AIO Studio',
            style: theme.typography.body?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );

    return SizedBox(
      height: 32,
      child: Row(
        children: [
          Expanded(
            child: PlatformUtils.isDesktop
                ? DragToMoveArea(child: titleContent)
                : titleContent,
          ),
          if (PlatformUtils.isDesktop) ...[
            _WindowButton(
              icon: WindowsIcons.chrome_minimize,
              onPressed: () async {
                if (await windowManager.isMinimized()) {
                  await windowManager.restore();
                } else {
                  await windowManager.minimize();
                }
              },
            ),
            _WindowButton(
              icon: _isMaximized
                  ? WindowsIcons.chrome_back_to_window
                  : WindowsIcons.chrome_maximize,
              onPressed: () async {
                if (_isMaximized) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
            ),
            _WindowButton(
              icon: WindowsIcons.chrome_close,
              onPressed: windowManager.close,
              isClose: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  const _WindowButton({
    required this.icon,
    required this.onPressed,
    this.isClose = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool isClose;

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color background;
    Color iconColor;

    if (_isHovered) {
      if (widget.isClose) {
        background = AppColors.error(theme.brightness);
        iconColor = AppColors.onAccent;
      } else {
        background = isDark
            ? AppColors.overlayLight(0.08)
            : AppColors.overlayDark(0.04);
        iconColor = theme.resources.textFillColorPrimary;
      }
    } else {
      background = Colors.transparent;
      iconColor = theme.resources.textFillColorPrimary;
    }

    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowHoverHighlight: (v) => setState(() => _isHovered = v),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onPressed();
            return null;
          },
        ),
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 46,
          height: 32,
          color: background,
          child: Center(child: Icon(widget.icon, size: 10, color: iconColor)),
        ),
      ),
    );
  }
}
