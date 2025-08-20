import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_shared/middleware/cors_config.dart';
import 'package:dart_frog_shared/middleware/cors_middleware.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockRequestContext extends Mock implements RequestContext {}

class _MockRequest extends Mock implements Request {}

class _MockResponse extends Mock implements Response {}

void main() {
  group('corsMiddleware', () {
    late RequestContext context;
    late Request request;
    late Response response;
    late Handler handler;

    setUp(() {
      context = _MockRequestContext();
      request = _MockRequest();
      response = _MockResponse();
      handler = (_) => Future.value(response);

      when(() => context.request).thenReturn(request);
      when(() => response.headers).thenReturn({});
      when(() => response.copyWith(headers: any(named: 'headers'))).thenReturn(response);
    });

    test('handles OPTIONS preflight request with default config', () async {
      when(() => request.method).thenReturn(HttpMethod.options);

      final middleware = corsMiddleware();
      final result = await middleware(handler)(context);

      expect(result.headers['Access-Control-Allow-Origin'], equals('*'));
      expect(result.headers['Access-Control-Allow-Methods'], equals('GET, POST, PUT, DELETE, OPTIONS'));
      expect(
        result.headers['Access-Control-Allow-Headers'],
        equals('Origin, Content-Type, Accept, Authorization, X-Requested-With, X-Firebase-AppCheck'),
      );
      expect(result.headers['Access-Control-Max-Age'], equals('86400'));
    });

    test('handles OPTIONS preflight request with custom config', () async {
      when(() => request.method).thenReturn(HttpMethod.options);

      const config = CorsConfig(
        allowedOrigins: ['https://example.com', 'https://app.example.com'],
        allowedMethods: ['GET', 'POST'],
        allowedHeaders: ['Content-Type', 'Authorization'],
        maxAge: Duration(hours: 12),
      );

      final middleware = corsMiddleware(config: config);
      final result = await middleware(handler)(context);

      expect(result.headers['Access-Control-Allow-Origin'], equals('https://example.com, https://app.example.com'));
      expect(result.headers['Access-Control-Allow-Methods'], equals('GET, POST'));
      expect(result.headers['Access-Control-Allow-Headers'], equals('Content-Type, Authorization'));
      expect(result.headers['Access-Control-Max-Age'], equals('43200'));
    });

    test('adds CORS headers to non-OPTIONS requests', () async {
      when(() => request.method).thenReturn(HttpMethod.get);

      final middleware = corsMiddleware();
      await middleware(handler)(context);

      verify(
        () => response.copyWith(
          headers: any(named: 'headers', that: containsPair('Access-Control-Allow-Origin', '*')),
        ),
      ).called(1);
    });

    test('preserves existing headers when adding CORS headers', () async {
      when(() => request.method).thenReturn(HttpMethod.post);
      when(() => response.headers).thenReturn({'X-Custom-Header': 'value'});

      final middleware = corsMiddleware();
      await middleware(handler)(context);

      verify(
        () => response.copyWith(
          headers: any(
            named: 'headers',
            that: allOf(containsPair('X-Custom-Header', 'value'), containsPair('Access-Control-Allow-Origin', '*')),
          ),
        ),
      ).called(1);
    });
  });
}
