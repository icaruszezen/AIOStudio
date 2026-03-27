import 'package:aio_studio/core/services/ai/ai_exceptions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiServiceException', () {
    test('stores all fields', () {
      const ex = AiServiceException(
        message: 'something broke',
        userMessage: '出错了',
        statusCode: 500,
        originalError: 'root cause',
      );

      expect(ex.message, 'something broke');
      expect(ex.userMessage, '出错了');
      expect(ex.statusCode, 500);
      expect(ex.originalError, 'root cause');
    });

    test('implements Exception', () {
      const ex = AiServiceException(message: 'err', userMessage: 'msg');

      expect(ex, isA<Exception>());
    });

    test('toString includes statusCode and message', () {
      const ex = AiServiceException(
        message: 'detail',
        userMessage: 'ui msg',
        statusCode: 503,
      );

      expect(ex.toString(), 'AiServiceException(503): detail');
    });

    test('toString with null statusCode', () {
      const ex = AiServiceException(message: 'no code', userMessage: 'ui');

      expect(ex.toString(), 'AiServiceException(null): no code');
    });
  });

  group('AuthenticationError', () {
    test('extends AiServiceException', () {
      const err = AuthenticationError(message: 'invalid key');
      expect(err, isA<AiServiceException>());
      expect(err, isA<Exception>());
    });

    test('has default userMessage', () {
      const err = AuthenticationError(message: 'bad api key');
      expect(err.userMessage, 'API 密钥无效或已过期，请检查服务商配置');
    });

    test('allows custom statusCode', () {
      const err = AuthenticationError(message: 'x', statusCode: 403);
      expect(err.statusCode, 403);
    });

    test('carries originalError', () {
      final cause = Exception('root');
      final err = AuthenticationError(message: 'x', originalError: cause);
      expect(err.originalError, cause);
    });
  });

  group('RateLimitError', () {
    test('extends AiServiceException', () {
      const err = RateLimitError(message: 'slow down');
      expect(err, isA<AiServiceException>());
    });

    test('default statusCode is 429', () {
      const err = RateLimitError(message: 'rate limited');
      expect(err.statusCode, 429);
    });

    test('default userMessage', () {
      const err = RateLimitError(message: 'x');
      expect(err.userMessage, '请求过于频繁，请稍后再试');
    });

    test('retryAfter field', () {
      const err = RateLimitError(
        message: 'x',
        retryAfter: Duration(seconds: 30),
      );

      expect(err.retryAfter, const Duration(seconds: 30));
    });

    test('retryAfter defaults to null', () {
      const err = RateLimitError(message: 'x');
      expect(err.retryAfter, isNull);
    });
  });

  group('InvalidRequestError', () {
    test('extends AiServiceException', () {
      const err = InvalidRequestError(message: 'bad param');
      expect(err, isA<AiServiceException>());
    });

    test('default statusCode is 400', () {
      const err = InvalidRequestError(message: 'x');
      expect(err.statusCode, 400);
    });

    test('default userMessage', () {
      const err = InvalidRequestError(message: 'x');
      expect(err.userMessage, '请求参数无效，请检查输入内容');
    });
  });

  group('NetworkError', () {
    test('extends AiServiceException', () {
      const err = NetworkError(message: 'timeout');
      expect(err, isA<AiServiceException>());
    });

    test('default userMessage about network', () {
      const err = NetworkError(message: 'x');
      expect(err.userMessage, '网络连接失败，请检查网络设置或代理配置');
    });

    test('statusCode defaults to null', () {
      const err = NetworkError(message: 'x');
      expect(err.statusCode, isNull);
    });
  });

  group('ServerError', () {
    test('extends AiServiceException', () {
      const err = ServerError(message: 'internal error');
      expect(err, isA<AiServiceException>());
    });

    test('default userMessage about service unavailable', () {
      const err = ServerError(message: 'x');
      expect(err.userMessage, 'AI 服务暂时不可用，请稍后重试');
    });

    test('statusCode defaults to null', () {
      const err = ServerError(message: 'x');
      expect(err.statusCode, isNull);
    });

    test('allows custom statusCode', () {
      const err = ServerError(message: 'x', statusCode: 502);
      expect(err.statusCode, 502);
    });
  });

  group('all exception types implement Exception', () {
    test('can be caught as Exception', () {
      final exceptions = <Exception>[
        const AiServiceException(message: 'a', userMessage: 'b'),
        const AuthenticationError(message: 'c'),
        const RateLimitError(message: 'd'),
        const InvalidRequestError(message: 'e'),
        const NetworkError(message: 'f'),
        const ServerError(message: 'g'),
      ];

      for (final ex in exceptions) {
        expect(ex, isA<Exception>());
        expect(ex, isA<AiServiceException>());
      }
    });
  });
}
