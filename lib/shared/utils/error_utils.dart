import 'package:aio_studio/core/services/ai/ai_exceptions.dart';

/// Converts any error into a user-friendly Chinese message.
///
/// Priority:
/// 1. [AiServiceException] → [AiServiceException.userMessage]
/// 2. [StateError] → its [message] (already written in Chinese in this project)
/// 3. Known network / timeout patterns → fixed Chinese strings
/// 4. Everything else → generic fallback
String formatUserError(Object error) {
  if (error is AiServiceException) return error.userMessage;

  if (error is StateError) return error.message;

  final msg = error.toString();

  if (msg.contains('SocketException') || msg.contains('Connection refused')) {
    return '网络连接失败，请检查网络设置或代理配置';
  }
  if (msg.contains('TimeoutException') || msg.contains('timed out')) {
    return '请求超时，请稍后重试';
  }
  if (msg.contains('FileSystemException')) {
    return '文件操作失败，请检查存储路径权限';
  }
  if (msg.contains('SqliteException') || msg.contains('DatabaseException')) {
    return '数据库操作失败，请重试';
  }

  return '操作失败，请稍后重试';
}
