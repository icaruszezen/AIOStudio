import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import 'ai_exceptions.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

/// Creates a [Dio] instance pre-configured for AI service calls.
///
/// The returned instance shares timeout settings, logging with API-key
/// masking, automatic retry on 429/5xx, and error-to-exception conversion.
Dio createAiDio({
  required String baseUrl,
  String? apiKey,
  Map<String, String>? extraHeaders,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 120),
      headers: {
        'Content-Type': 'application/json',
        if (apiKey != null) 'Authorization': 'Bearer $apiKey',
        ...?extraHeaders,
      },
    ),
  );

  dio.interceptors.addAll([
    AiLogInterceptor(),
    AiRetryInterceptor(),
    AiErrorInterceptor(),
  ]);

  return dio;
}

// ---------------------------------------------------------------------------
// Log interceptor – masks Authorization / x-api-key values
// ---------------------------------------------------------------------------

class AiLogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final masked = _maskHeaders(options.headers);
    _log.d(
      '[AI] → ${options.method} ${options.uri}\n'
      '  headers: $masked',
    );
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _log.d('[AI] ← ${response.statusCode} ${response.requestOptions.uri}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _log.e(
      '[AI] ✗ ${err.requestOptions.uri} – '
      '${err.response?.statusCode ?? err.type}: ${err.message}',
    );
    handler.next(err);
  }

  static Map<String, dynamic> _maskHeaders(Map<String, dynamic> headers) {
    final result = Map<String, dynamic>.from(headers);
    for (final key in ['Authorization', 'authorization', 'x-api-key']) {
      if (result.containsKey(key)) {
        result[key] = _maskValue(result[key].toString());
      }
    }
    return result;
  }

  static String _maskValue(String value) {
    final raw = value.replaceFirst(
      RegExp(r'^Bearer\s+', caseSensitive: false),
      '',
    );
    if (raw.length <= 4) return '****';
    return '${raw.substring(0, 4)}****';
  }
}

// ---------------------------------------------------------------------------
// Retry interceptor – exponential back-off for 429 / 5xx, max 3 attempts
// ---------------------------------------------------------------------------

class AiRetryInterceptor extends QueuedInterceptor {
  static const _maxRetries = 3;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (!_isRetryable(err)) {
      handler.next(err);
      return;
    }

    final options = err.requestOptions;
    DioException lastError = err;

    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      final delay = Duration(milliseconds: pow(2, attempt).toInt() * 1000);
      _log.w(
        '[AI] Retry ${attempt + 1}/$_maxRetries after ${delay.inSeconds}s '
        '(status ${lastError.response?.statusCode})',
      );
      await Future<void>.delayed(delay);

      Dio? retryDio;
      try {
        retryDio = Dio(
          BaseOptions(
            headers: options.headers,
            connectTimeout: options.connectTimeout,
            receiveTimeout: options.receiveTimeout,
          ),
        );
        retryDio.interceptors.add(AiLogInterceptor());
        final response = await retryDio.fetch(options);
        _log.i('[AI] Retry succeeded for ${options.uri}');
        handler.resolve(response);
        return;
      } on DioException catch (e) {
        lastError = e;
        if (!_isRetryable(e)) break;
      } finally {
        retryDio?.close();
      }
    }

    _log.e('[AI] All $_maxRetries retries exhausted for ${options.uri}');
    handler.next(lastError);
  }

  static bool _isRetryable(DioException err) {
    final status = err.response?.statusCode;
    return status == 429 || (status != null && status >= 500);
  }
}

// ---------------------------------------------------------------------------
// Error interceptor – converts DioException → AiServiceException subtypes
// ---------------------------------------------------------------------------

class AiErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final status = err.response?.statusCode;
    final body = err.response?.data;
    final detail = _extractErrorMessage(body) ?? err.message ?? 'Unknown error';

    AiServiceException mapped;

    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        mapped = NetworkError(
          message: detail,
          statusCode: status,
          originalError: err,
        );
        handler.reject(_wrap(err, mapped));
        return;
      default:
        break;
    }

    if (status == null) {
      mapped = NetworkError(message: detail, originalError: err);
      handler.reject(_wrap(err, mapped));
      return;
    }

    if (status == 401 || status == 403) {
      mapped = AuthenticationError(
        message: detail,
        statusCode: status,
        originalError: err,
      );
    } else if (status == 429) {
      final retryAfter = _parseRetryAfter(err.response?.headers);
      mapped = RateLimitError(
        message: detail,
        retryAfter: retryAfter,
        originalError: err,
      );
    } else if (status == 400 || status == 422) {
      mapped = InvalidRequestError(
        message: detail,
        statusCode: status,
        originalError: err,
      );
    } else if (status >= 500) {
      mapped = ServerError(
        message: detail,
        statusCode: status,
        originalError: err,
      );
    } else {
      mapped = AiServiceException(
        message: detail,
        userMessage: '请求失败 ($status)',
        statusCode: status,
        originalError: err,
      );
    }

    handler.reject(_wrap(err, mapped));
  }

  static String? _extractErrorMessage(dynamic body) {
    if (body is Map<String, dynamic>) {
      final error = body['error'];
      if (error is Map<String, dynamic>) return error['message'] as String?;
      if (error is String) return error;
      return body['message'] as String?;
    }
    return null;
  }

  static DioException _wrap(DioException original, AiServiceException mapped) {
    return DioException(
      requestOptions: original.requestOptions,
      response: original.response,
      type: original.type,
      error: mapped,
      message: original.message,
    );
  }

  static Duration? _parseRetryAfter(Headers? headers) {
    final value = headers?.value('retry-after');
    if (value == null) return null;
    final seconds = int.tryParse(value);
    return seconds != null ? Duration(seconds: seconds) : null;
  }
}
