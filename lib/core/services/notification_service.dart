import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// Lightweight in-app notification service.
///
/// Uses a global navigator key to display [InfoBar] notifications.
/// Can be extended with platform-level desktop notifications later.
class NotificationService {
  static final _log = Logger(printer: PrettyPrinter(methodCount: 0));

  static final navigatorKey = GlobalKey<NavigatorState>();

  void show({
    required String title,
    String? message,
    bool isError = false,
  }) {
    final context = navigatorKey.currentContext;
    if (context == null) {
      _log.w('[Notification] No context available for notification: $title');
      return;
    }

    displayInfoBar(context, builder: (ctx, close) {
      return InfoBar(
        title: Text(title),
        content: message != null ? Text(message) : null,
        severity: isError ? InfoBarSeverity.error : InfoBarSeverity.success,
        onClose: close,
      );
    });
  }
}
