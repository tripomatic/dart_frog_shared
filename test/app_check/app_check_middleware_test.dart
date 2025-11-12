import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_shared/app_check/app_check_config.dart';
import 'package:dart_frog_shared/app_check/app_check_middleware.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockRequestContext extends Mock implements RequestContext {}

class _MockRequest extends Mock implements Request {}

void main() {
  group('appCheckMiddleware', () {
    late RequestContext context;
    late Request request;
    late Handler handler;
    late Response response;

    setUp(() {
      context = _MockRequestContext();
      request = _MockRequest();
      response = Response(body: 'Success');
      handler = (_) => Future.value(response);

      when(() => context.request).thenReturn(request);
      when(() => request.uri).thenReturn(Uri.parse('/test'));
      when(() => request.headers).thenReturn({});
      when(() => request.method).thenReturn(HttpMethod.get); // Default to GET for non-OPTIONS tests
    });

    test('should bypass App Check in dev mode', () async {
      const config = AppCheckConfig(
        firebaseProjectId: 'test-project',
        serviceAccountJson: '{"type": "service_account"}',
        enableDevMode: true,
      );

      final middleware = appCheckMiddleware(config: config);
      final middlewareHandler = middleware(handler);

      final result = await middlewareHandler(context);

      expect(result, equals(response));
    });

    test('should bypass App Check for OPTIONS preflight requests', () async {
      const config = AppCheckConfig(
        firebaseProjectId: 'test-project',
        serviceAccountJson: '{"type": "service_account"}',
      );

      when(() => request.method).thenReturn(HttpMethod.options);

      final middleware = appCheckMiddleware(config: config);
      final middlewareHandler = middleware(handler);

      final result = await middlewareHandler(context);

      expect(result, equals(response));
    });

    test('should bypass App Check for exempt paths', () async {
      const config = AppCheckConfig(
        firebaseProjectId: 'test-project',
        serviceAccountJson: '{"type": "service_account"}',
        exemptPaths: ['/ping'],
      );

      when(() => request.uri).thenReturn(Uri.parse('/ping'));

      final middleware = appCheckMiddleware(config: config);
      final middlewareHandler = middleware(handler);

      final result = await middlewareHandler(context);

      expect(result, equals(response));
    });

    test('should return 401 for missing App Check header', () async {
      const config = AppCheckConfig(
        firebaseProjectId: 'test-project',
        serviceAccountJson: '{"type": "service_account"}',
      );

      final middleware = appCheckMiddleware(config: config);
      final middlewareHandler = middleware(handler);

      final result = await middlewareHandler(context);

      expect(result.statusCode, equals(HttpStatus.unauthorized));
    });

    test('should return 401 for empty App Check header', () async {
      const config = AppCheckConfig(
        firebaseProjectId: 'test-project',
        serviceAccountJson: '{"type": "service_account"}',
      );

      when(() => request.headers).thenReturn({'X-Firebase-AppCheck': ''});

      final middleware = appCheckMiddleware(config: config);
      final middlewareHandler = middleware(handler);

      final result = await middlewareHandler(context);

      expect(result.statusCode, equals(HttpStatus.unauthorized));
    });
  });
}
