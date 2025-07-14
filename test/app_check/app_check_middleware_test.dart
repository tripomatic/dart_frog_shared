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
      handler = (_) async => response;

      when(() => context.request).thenReturn(request);
      when(() => request.uri).thenReturn(Uri.parse('/test'));
      when(() => request.headers).thenReturn({});
    });

    test('should bypass App Check in dev mode', () async {
      const config = AppCheckConfig(
        firebaseProjectId: 'test-project',
        serviceAccountJson: 'base64-json',
        enableDevMode: true,
      );

      final middleware = appCheckMiddleware(config: config);
      final middlewareHandler = middleware(handler);

      final result = await middlewareHandler(context);

      expect(result, equals(response));
    });

    test('should bypass App Check for exempt paths', () async {
      const config = AppCheckConfig(
        firebaseProjectId: 'test-project',
        serviceAccountJson: 'base64-json',
        exemptPaths: ['/ping'],
      );

      when(() => request.uri).thenReturn(Uri.parse('/ping'));

      final middleware = appCheckMiddleware(config: config);
      final middlewareHandler = middleware(handler);

      final result = await middlewareHandler(context);

      expect(result, equals(response));
    });

    test('should return 401 for missing App Check header', () async {
      const config = AppCheckConfig(firebaseProjectId: 'test-project', serviceAccountJson: 'base64-json');

      final middleware = appCheckMiddleware(config: config);
      final middlewareHandler = middleware(handler);

      final result = await middlewareHandler(context);

      expect(result.statusCode, equals(HttpStatus.unauthorized));
    });

    test('should return 401 for empty App Check header', () async {
      const config = AppCheckConfig(firebaseProjectId: 'test-project', serviceAccountJson: 'base64-json');

      when(() => request.headers).thenReturn({'X-Firebase-AppCheck': ''});

      final middleware = appCheckMiddleware(config: config);
      final middlewareHandler = middleware(handler);

      final result = await middlewareHandler(context);

      expect(result.statusCode, equals(HttpStatus.unauthorized));
    });
  });
}
