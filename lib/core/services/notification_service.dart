import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// Lightweight in-app notification service.
///
/// Uses a global navigator key to display [InfoBar] notifications.
/// Includes simple throttle: duplicate titles within [_throttleWindow] are
/// suppressed to avoid flooding the UI during batch operations.
class NotificationService {
  static final _log = Logger(printer: PrettyPrinter(methodCount: 0));

  static final navigatorKey = GlobalKey<NavigatorState>();

  static const _throttleWindow = Duration(seconds: 2);
  final _recentTitles = <String, DateTime>{};

  void show({
    required String title,
    String? message,
    InfoBarSeverity severity = InfoBarSeverity.success,
    Widget Function(VoidCallback close)? actionBuilder,
    @Deprecated('Use severity instead') bool isError = false,
  }) {
    // ignore: deprecated_member_use_from_same_package
    final effectiveSeverity = isError ? InfoBarSeverity.error : severity;

    final now = DateTime.now();
    final lastShown = _recentTitles[title];
    if (lastShown != null && now.difference(lastShown) < _throttleWindow) {
      return;
    }
    _recentTitles[title] = now;

    // Prune stale entries to avoid unbounded growth.
    _recentTitles.removeWhere(
        (_, t) => now.difference(t) > const Duration(seconds: 10));

    final context = navigatorKey.currentContext;
    if (context == null) {
      _log.w('[Notification] No context available for notification: $title');
      return;
    }

    displayInfoBar(context, builder: (ctx, close) {
      return InfoBar(
        title: Text(title),
        content: message != null ? Text(message) : null,
        severity: effectiveSeverity,
        action: actionBuilder?.call(close),
        onClose: close,
      );
    });
  }
}
