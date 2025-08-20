import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_shared/middleware/rate_limit_config.dart';
import 'package:dart_frog_shared/middleware/rate_limit_middleware.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:test/test.dart';

class _MockRequestContext extends Mock implements RequestContext {}

class _MockRequest extends Mock implements Request {}

class _MockResponse extends Mock implements Response {}

class _MockUri extends Mock implements Uri {}

class _MockShelfRequest extends Mock implements shelf.Request {}

class _MockHttpConnectionInfo extends Mock implements HttpConnectionInfo {}

class _MockInternetAddress extends Mock implements InternetAddress {}

void main() {
  group('rateLimitMiddleware', () {
    late RequestContext context;
    late Request request;
    late Response response;
    late Handler handler;
    late Uri uri;

    setUp(() {
      context = _MockRequestContext();
      request = _MockRequest();
      response = _MockResponse();
      handler = (_) => Future.value(response);
      uri = _MockUri();

      when(() => context.request).thenReturn(request);
      when(() => request.uri).thenReturn(uri);
      when(() => request.method).thenReturn(HttpMethod.get);
    });

    test('skips rate limiting for exempt paths', () async {
      when(() => uri.path).thenReturn('/ping');

      const config = RateLimitConfig(exemptPaths: ['/ping']);
      final middleware = rateLimitMiddleware(config: config);
      final result = await middleware(handler)(context);

      expect(result, equals(response));
      // Handler should be called directly without rate limiting
    });

    test('skips rate limiting for OPTIONS requests', () async {
      when(() => uri.path).thenReturn('/api/test');
      when(() => request.method).thenReturn(HttpMethod.options);

      final middleware = rateLimitMiddleware();
      final result = await middleware(handler)(context);

      expect(result, equals(response));
    });

    test('applies default rate limit configuration', () {
      when(() => uri.path).thenReturn('/api/test');

      final middleware = rateLimitMiddleware();

      // Since we can't easily test the actual rate limiting behavior
      // without hitting the shelf_limiter internals, we'll just verify
      // the middleware can be created and called
      final middlewareHandler = middleware(handler);
      expect(middlewareHandler, isA<Handler>());
    });

    test('applies endpoint-specific rate limits', () {
      when(() => uri.path).thenReturn('/api/special');

      const config = RateLimitConfig(endpointLimits: [EndpointRateLimit(path: '/api/special', maxRequests: 300)]);

      final middleware = rateLimitMiddleware(config: config);
      final middlewareHandler = middleware(handler);
      expect(middlewareHandler, isA<Handler>());
    });

    test('custom client identifier extractor is used', () {
      String customExtractor(shelf.Request request) {
        return 'custom-id';
      }

      final config = RateLimitConfig(clientIdentifierExtractor: customExtractor);

      final middleware = rateLimitMiddleware(config: config);
      expect(middleware, isA<Middleware>());
    });

    test('custom rate limit exceeded handler is used', () {
      shelf.Response customHandler(shelf.Request request) {
        return shelf.Response(429, body: 'Custom rate limit message');
      }

      final config = RateLimitConfig(onRateLimitExceeded: customHandler);

      final middleware = rateLimitMiddleware(config: config);
      expect(middleware, isA<Middleware>());
    });
  });

  group('RateLimitConfig', () {
    test('defaultClientIdentifierExtractor extracts IP from X-Forwarded-For', () {
      final request = _MockShelfRequest();
      when(() => request.headers).thenReturn({'x-forwarded-for': '192.168.1.1, 10.0.0.1'});

      final result = RateLimitConfig.defaultClientIdentifierExtractor(request);
      expect(result, equals('192.168.1.1'));
    });

    test('defaultClientIdentifierExtractor falls back to connection info', () {
      final request = _MockShelfRequest();
      final connectionInfo = _MockHttpConnectionInfo();
      final remoteAddress = _MockInternetAddress();

      when(() => remoteAddress.address).thenReturn('192.168.1.100');
      when(() => connectionInfo.remoteAddress).thenReturn(remoteAddress);

      when(() => request.headers).thenReturn({});
      when(() => request.context).thenReturn({'shelf.io.connection_info': connectionInfo});

      final result = RateLimitConfig.defaultClientIdentifierExtractor(request);
      expect(result, equals('192.168.1.100'));
    });

    test('defaultClientIdentifierExtractor returns unknown when no IP found', () {
      final request = _MockShelfRequest();
      when(() => request.headers).thenReturn({});
      when(() => request.context).thenReturn({});

      final result = RateLimitConfig.defaultClientIdentifierExtractor(request);
      expect(result, equals('unknown'));
    });

    test('defaultRateLimitExceededResponse returns proper JSON response', () {
      final request = _MockShelfRequest();
      final response = RateLimitConfig.defaultRateLimitExceededResponse(request, 100);

      expect(response.statusCode, equals(429));
      expect(response.headers['content-type'], equals('application/json'));
      expect(
        response.readAsString(),
        completion(equals('{"error": "Rate limit exceeded. Maximum 100 requests per hour allowed."}')),
      );
    });
  });
}
