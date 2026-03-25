import '../../core/services/ai/ai_exceptions.dart';
import '../../l10n/app_localizations.dart';

/// Converts any error into a user-friendly localized message.
///
/// When [l] is provided, returns a properly localized string.
/// When [l] is null (e.g. called from a provider without BuildContext),
/// falls back to Chinese.
///
/// Priority:
/// 1. [AiServiceException] → [AiServiceException.userMessage]
/// 2. [StateError] → its [message]
/// 3. Known network / timeout patterns → localized strings
/// 4. Everything else → generic fallback
String formatUserError(Object error, [S? l]) {
  if (error is AiServiceException) return error.userMessage;

  if (error is StateError) return error.message;

  final msg = error.toString();

  if (msg.contains('SocketException') || msg.contains('Connection refused')) {
    return l?.errorNetwork ?? '网络连接失败，请检查网络设置或代理配置';
  }
  if (msg.contains('TimeoutException') || msg.contains('timed out')) {
    return l?.errorTimeout ?? '请求超时，请稍后重试';
  }
  if (msg.contains('FileSystemException')) {
    return l?.errorFileSystem ?? '文件操作失败，请检查存储路径权限';
  }
  if (msg.contains('SqliteException') || msg.contains('DatabaseException')) {
    return l?.errorDatabase ?? '数据库操作失败，请重试';
  }

  return l?.errorGeneric ?? '操作失败，请稍后重试';
}
