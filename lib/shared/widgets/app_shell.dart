import 'package:fluent_ui/fluent_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/router/app_router.dart';
import '../../core/utils/platform_utils.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WindowListener {
  /// Ordered list of route paths matching the selectable PaneItem indices.
  /// PaneItemSeparator does not occupy an index.
  static const _routes = [
    AppRoutes.projects, // 0
    AppRoutes.assets, // 1
    // -- separator (no index) --
    AppRoutes.aiChat, // 2
    AppRoutes.aiImage, // 3
    AppRoutes.aiVideo, // 4
    AppRoutes.prompts, // 5
    AppRoutes.settings, // 6 (footer)
  ];

  bool _isMaximized = false;

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
    for (var i = 0; i < _routes.length; i++) {
      if (location == _routes[i] || location.startsWith('${_routes[i]}/')) {
        return i;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth <= Breakpoints.tablet;

        Widget content = NavigationView(
          titleBar: PlatformUtils.isMobile
              ? const SizedBox.shrink()
              : _buildTitleBar(context),
          pane: NavigationPane(
            selected: selectedIndex,
            onChanged: (index) {
              if (index >= 0 && index < _routes.length) {
                context.go(_routes[index]);
              }
            },
            displayMode:
                isNarrow ? PaneDisplayMode.minimal : PaneDisplayMode.auto,
            // Work around fluent_ui 4.14.0 bug: when header is null and the
            // toggle button is not in the pane, paneHeaderHeight is set to
            // -1.0, causing BoxConstraints to become invalid.
            header: const SizedBox.shrink(),
            items: [
              PaneItem(
                icon: const Icon(FluentIcons.project_management),
                title: const Text('项目管理'),
                body: const SizedBox.shrink(),
              ),
              PaneItem(
                icon: const Icon(FluentIcons.photo_collection),
                title: const Text('资产库'),
                body: const SizedBox.shrink(),
              ),
              PaneItemSeparator(),
              PaneItem(
                icon: const Icon(FluentIcons.chat),
                title: const Text('AI 对话'),
                body: const SizedBox.shrink(),
              ),
              PaneItem(
                icon: const Icon(FluentIcons.image_search),
                title: const Text('图片生成'),
                body: const SizedBox.shrink(),
              ),
              PaneItem(
                icon: const Icon(FluentIcons.video),
                title: const Text('视频生成'),
                body: const SizedBox.shrink(),
              ),
              PaneItem(
                icon: const Icon(FluentIcons.text_document),
                title: const Text('提示词库'),
                body: const SizedBox.shrink(),
              ),
            ],
            footerItems: [
              PaneItem(
                icon: const Icon(FluentIcons.settings),
                title: const Text('设置'),
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
          Icon(FluentIcons.app_icon_default, size: 16, color: theme.accentColor),
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
        background = Colors.red;
        iconColor = Colors.white;
      } else {
        background = isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.04);
        iconColor = theme.resources.textFillColorPrimary;
      }
    } else {
      background = Colors.transparent;
      iconColor = theme.resources.textFillColorPrimary;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 46,
          height: 32,
          color: background,
          child: Center(
            child: Icon(widget.icon, size: 10, color: iconColor),
          ),
        ),
      ),
    );
  }
}
