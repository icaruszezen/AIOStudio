import 'package:shelf/shelf.dart';

const _maxBodyBytes = 200 * 1024 * 1024; // 200 MB

/// Adds CORS headers and handles OPTIONS preflight requests.
Middleware corsMiddleware() {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers':
        'Content-Type, X-AIO-Client, Origin, Accept',
    'Access-Control-Max-Age': '86400',
  };

  return (Handler innerHandler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: corsHeaders);
      }
      final response = await innerHandler(request);
      return response.change(headers: corsHeaders);
    };
  };
}

/// Validates the request origin – accepts browser-extension origins
/// (`chrome-extension://`, `moz-extension://`) and the custom header.
Middleware originCheckMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') return innerHandler(request);

      final origin = request.headers['origin'] ?? '';
      final aioClient = request.headers['x-aio-client'] ?? '';

      final trusted = origin.startsWith('chrome-extension://') ||
          origin.startsWith('moz-extension://') ||
          origin.startsWith('safari-web-extension://') ||
          origin.isEmpty || // same-origin / curl / Postman
          aioClient == 'browser-extension';

      if (!trusted) {
        return Response.forbidden('{"error":"Untrusted origin"}',
            headers: {'Content-Type': 'application/json'});
      }
      return innerHandler(request);
    };
  };
}

/// Rejects requests whose Content-Length exceeds [_maxBodyBytes].
Middleware requestSizeLimitMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      final cl = request.headers['content-length'];
      if (cl != null) {
        final size = int.tryParse(cl) ?? 0;
        if (size > _maxBodyBytes) {
          return Response(413,
              body: '{"error":"Request body too large (max 200 MB)"}',
              headers: {'Content-Type': 'application/json'});
        }
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
        return Response(429,
            body: '{"error":"Too many requests"}',
            headers: {
              'Content-Type': 'application/json',
              'Retry-After': '1',
            });
      }
      timestamps.add(now);
      return innerHandler(request);
    };
  };
}
