import 'dart:convert';

import 'package:shelf/shelf.dart';

const _maxBodyBytes = 200 * 1024 * 1024; // 200 MB
const _jsonHeaders = {'Content-Type': 'application/json'};

bool _isTrustedOrigin(String origin) {
  return origin.startsWith('chrome-extension://') ||
      origin.startsWith('moz-extension://') ||
      origin.startsWith('safari-web-extension://');
}

Response _errorResponse(int statusCode, String message) {
  return Response(
    statusCode,
    body: jsonEncode({'success': false, 'error': message}),
    headers: _jsonHeaders,
  );
}

/// Validates a bearer token on all requests except health-check.
Middleware tokenAuthMiddleware(String expectedToken) {
  return (Handler innerHandler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') return innerHandler(request);

      final path = request.requestedUri.path;
      if (path == '/api/health') return innerHandler(request);

      final auth = request.headers['authorization'] ?? '';
      final token = auth.startsWith('Bearer ')
          ? auth.substring('Bearer '.length).trim()
          : '';

      if (token != expectedToken) {
        return _errorResponse(403, 'Invalid or missing auth token');
      }
      return innerHandler(request);
    };
  };
}

/// Adds CORS headers and handles OPTIONS preflight requests.
/// Only reflects the request Origin when it comes from a trusted
/// browser-extension scheme; non-browser clients (curl, Postman) don't
/// need CORS headers.
Middleware corsMiddleware() {
  const baseCorsHeaders = {
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers':
        'Content-Type, Origin, Accept, Authorization',
    'Access-Control-Max-Age': '86400',
  };

  return (Handler innerHandler) {
    return (Request request) async {
      final origin = request.headers['origin'] ?? '';
      final corsHeaders = {
        ...baseCorsHeaders,
        if (_isTrustedOrigin(origin)) 'Access-Control-Allow-Origin': origin,
      };

      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: corsHeaders);
      }
      final response = await innerHandler(request);
      return response.change(headers: corsHeaders);
    };
  };
}

/// Validates the request origin – accepts browser-extension origins and
/// empty origin (non-browser clients like curl/Postman that will still be
/// authenticated by [tokenAuthMiddleware] further down the pipeline).
Middleware originCheckMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') return innerHandler(request);

      final origin = request.headers['origin'] ?? '';

      final trusted = _isTrustedOrigin(origin) || origin.isEmpty;

      if (!trusted) {
        return _errorResponse(403, 'Untrusted origin');
      }
      return innerHandler(request);
    };
  };
}

/// Rejects requests whose Content-Length exceeds [_maxBodyBytes].
/// For chunked transfers without Content-Length, the body is read with a
/// hard byte limit to prevent unbounded memory usage.
Middleware requestSizeLimitMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      final cl = request.headers['content-length'];
      if (cl != null) {
        final size = int.tryParse(cl) ?? 0;
        if (size > _maxBodyBytes) {
          return _errorResponse(413, 'Request body too large (max 200 MB)');
        }
      } else if (request.method == 'POST' || request.method == 'PUT') {
        int totalBytes = 0;
        final chunks = <List<int>>[];
        await for (final chunk in request.read()) {
          totalBytes += chunk.length;
          if (totalBytes > _maxBodyBytes) {
            return _errorResponse(413, 'Request body too large (max 200 MB)');
          }
          chunks.add(chunk);
        }
        return innerHandler(request.change(body: Stream.fromIterable(chunks)));
      }
      return innerHandler(request);
    };
  };
}

/// Simple sliding-window rate limiter (max [maxRequests] per second).
Middleware rateLimitMiddleware({int maxRequests = 10}) {
  final timestamps = <DateTime>[];

  return (Handler innerHandler) {
    return (Request request) async {
      final now = DateTime.now();
      final windowStart = now.subtract(const Duration(seconds: 1));
      timestamps.removeWhere((t) => t.isBefore(windowStart));

      if (timestamps.length >= maxRequests) {
        final resp = _errorResponse(429, 'Too many requests');
        return resp.change(headers: {'Retry-After': '1'});
      }
      timestamps.add(now);
      return innerHandler(request);
    };
  };
}
