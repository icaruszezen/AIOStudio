/// Unified exception hierarchy for all AI service operations.
///
/// Each subtype maps to a specific HTTP status code range and carries
/// a [userMessage] suitable for display in the UI (Chinese).
class AiServiceException implements Exception {
  final String message;
  final String userMessage;
  final int? statusCode;
  final dynamic originalError;

  const AiServiceException({
    required this.message,
    required this.userMessage,
    this.statusCode,
    this.originalError,
  });

  @override
  String toString() => 'AiServiceException($statusCode): $message';
}

class AuthenticationError extends AiServiceException {
  const AuthenticationError({
    required super.message,
    super.statusCode,
    super.originalError,
    super.userMessage = 'API 密钥无效或已过期，请检查服务商配置',
  });
}

class RateLimitError extends AiServiceException {
  final Duration? retryAfter;

  const RateLimitError({
    required super.message,
    this.retryAfter,
    super.statusCode = 429,
    super.originalError,
    super.userMessage = '请求过于频繁，请稍后再试',
  });
}

class InvalidRequestError extends AiServiceException {
  const InvalidRequestError({
    required super.message,
    super.statusCode = 400,
    super.originalError,
    super.userMessage = '请求参数无效，请检查输入内容',
  });
}

class NetworkError extends AiServiceException {
  const NetworkError({
    required super.message,
    super.statusCode,
    super.originalError,
    super.userMessage = '网络连接失败，请检查网络设置或代理配置',
  });
}

class ServerError extends AiServiceException {
  const ServerError({
    required super.message,
    super.statusCode,
    super.originalError,
    super.userMessage = 'AI 服务暂时不可用，请稍后重试',
  });
}
