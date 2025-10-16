// ignore_for_file: prefer_function_declarations_over_variables, void_checks

import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_shared/exceptions/exceptions.dart';
import 'package:dart_frog_shared/middleware/error_handler_middleware.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockRequestContext extends Mock implements RequestContext {}

class _MockLogger extends Mock implements Logger {}

class _FakeException implements Exception {
  @override
  String toString() => 'FakeException';
}

class _FakeStackTrace implements StackTrace {
  @override
  String toString() => 'FakeStackTrace';
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeException());
    registerFallbackValue(_FakeStackTrace());
    registerFallbackValue(BadRequestException(message: 'fake'));
    registerFallbackValue(ArgumentError('fake'));
    registerFallbackValue(StateError('fake'));
  });

  group('errorHandlerMiddleware', () {
    late RequestContext context;
    late Logger logger;

    setUp(() {
      context = _MockRequestContext();
      logger = _MockLogger();

      when(() => context.read<Logger>()).thenReturn(logger);
      when(() => logger.warning(any(), any(), any())).thenAnswer((_) {});
      when(() => logger.severe(any(), any(), any())).thenAnswer((_) {});
    });

    test('passes through successful responses unchanged', () async {
      final handler = (_) => Future.value(Response.json(body: {'success': true}));

      final middleware = errorHandlerMiddleware();
      final result = await middleware(handler)(context);

      expect(result.statusCode, equals(200));
      final body = jsonDecode(await result.body()) as Map<String, dynamic>;
      expect(body['success'], equals(true));

      verifyNever(() => logger.warning(any(), any(), any()));
      verifyNever(() => logger.severe(any(), any(), any()));
    });

    test('catches BadRequestException and returns 400 response', () async {
      final exception = BadRequestException(
        message: 'Internal: Invalid input format',
        responseBodyMessage: 'Invalid input',
      );

      final handler = (_) => throw exception;

      final middleware = errorHandlerMiddleware();
      final result = await middleware(handler)(context);

      expect(result.statusCode, equals(400));
      final body = jsonDecode(await result.body()) as Map<String, dynamic>;
      expect(body['status'], equals(400));
      expect(body['error'], equals('Invalid input'));
      expect(body['debug_message'], isNull);

      verify(() => logger.warning('API error: Internal: Invalid input format', exception, any())).called(1);
      verifyNever(() => logger.severe(any(), any(), any()));
    });

    test('catches UnauthorizedException and returns 401 response', () async {
      final exception = UnauthorizedException(
        message: 'Token expired at 2025-10-16',
        responseBodyMessage: 'Unauthorized',
      );

      final handler = (_) => throw exception;

      final middleware = errorHandlerMiddleware();
      final result = await middleware(handler)(context);

      expect(result.statusCode, equals(401));
      final body = jsonDecode(await result.body()) as Map<String, dynamic>;
      expect(body['status'], equals(401));
      expect(body['error'], equals('Unauthorized'));
      expect(body['debug_message'], isNull);

      verify(() => logger.warning('API error: Token expired at 2025-10-16', exception, any())).called(1);
    });

    test('catches NotFoundException and returns 404 response', () async {
      final exception = NotFoundException(
        message: 'User ID 123 not found in database',
        responseBodyMessage: 'Resource not found',
      );

      final handler = (_) => throw exception;

      final middleware = errorHandlerMiddleware();
      final result = await middleware(handler)(context);

      expect(result.statusCode, equals(404));
      final body = jsonDecode(await result.body()) as Map<String, dynamic>;
      expect(body['status'], equals(404));
      expect(body['error'], equals('Resource not found'));

      verify(() => logger.warning('API error: User ID 123 not found in database', exception, any())).called(1);
    });

    test('catches MethodNotAllowedException and returns 405 response', () async {
      final exception = MethodNotAllowedException(
        message: 'POST method not allowed on GET-only endpoint',
        responseBodyMessage: 'Method not allowed',
      );

      final handler = (_) => throw exception;

      final middleware = errorHandlerMiddleware();
      final result = await middleware(handler)(context);

      expect(result.statusCode, equals(405));
      final body = jsonDecode(await result.body()) as Map<String, dynamic>;
      expect(body['status'], equals(405));
      expect(body['error'], equals('Method not allowed'));

      verify(
        () => logger.warning('API error: POST method not allowed on GET-only endpoint', exception, any()),
      ).called(1);
    });

    test('catches ConflictException and returns 409 response', () async {
      final exception = ConflictException(
        message: 'Resource already exists with ID 456',
        responseBodyMessage: 'Resource already exists',
      );

      final handler = (_) => throw exception;

      final middleware = errorHandlerMiddleware();
      final result = await middleware(handler)(context);

      expect(result.statusCode, equals(409));
      final body = jsonDecode(await result.body()) as Map<String, dynamic>;
      expect(body['status'], equals(409));
      expect(body['error'], equals('Resource already exists'));

      verify(() => logger.warning('API error: Resource already exists with ID 456', exception, any())).called(1);
    });

    test('catches InternalServerErrorException and returns 500 response', () async {
      final exception = InternalServerErrorException(
        message: 'Database connection failed: timeout',
        responseBodyMessage: 'Internal server error',
      );

      final handler = (_) => throw exception;

      final middleware = errorHandlerMiddleware();
      final result = await middleware(handler)(context);

      expect(result.statusCode, equals(500));
      final body = jsonDecode(await result.body()) as Map<String, dynamic>;
      expect(body['status'], equals(500));
      expect(body['error'], equals('Internal server error'));

      verify(() => logger.severe('API error: Database connection failed: timeout', exception, any())).called(1);
    });

    test('catches DataException and returns 500 response', () async {
      final exception = DataException(message: 'Invalid data format in field X', responseBodyMessage: 'Data error');

      final handler = (_) => throw exception;

      final middleware = errorHandlerMiddleware();
      final result = await middleware(handler)(context);

      expect(result.statusCode, equals(500));
      final body = jsonDecode(await result.body()) as Map<String, dynamic>;
      expect(body['status'], equals(500));
      expect(body['error'], equals('Data error'));

      verify(() => logger.severe('API error: Invalid data format in field X', exception, any())).called(1);
    });

    test('includes debug_message when debug mode is enabled', () async {
      final exception = BadRequestException(
        message: 'Internal debug: Field validation failed at line 42',
        responseBodyMessage: 'Invalid request',
      );

      final handler = (_) => throw exception;

      final middleware = errorHandlerMiddleware(debug: true);
      final result = await middleware(handler)(context);

      expect(result.statusCode, equals(400));
      final body = jsonDecode(await result.body()) as Map<String, dynamic>;
      expect(body['status'], equals(400));
      expect(body['error'], equals('Invalid request'));
      expect(body['debug_message'], equals('Internal debug: Field validation failed at line 42'));

      verify(() => logger.warning(any(), exception, any())).called(1);
    });

    test('catches generic exception and wraps in InternalServerErrorException', () async {
      final handler = (_) => throw Exception('Unexpected null pointer');

      final middleware = errorHandlerMiddleware();
      final result = await middleware(handler)(context);

      expect(result.statusCode, equals(500));
      final body = jsonDecode(await result.body()) as Map<String, dynamic>;
      expect(body['status'], equals(500));
      expect(body['error'], equals('Internal server error'));
      expect(body['debug_message'], isNull);

      verify(
        () => logger.severe('Unexpected error: Exception: Unexpected null pointer', any<Exception>(), any()),
      ).called(1);
    });

    test('catches generic exception and includes debug info when debug mode enabled', () async {
      final handler = (_) => throw ArgumentError('Invalid argument: value must be positive');

      final middleware = errorHandlerMiddleware(debug: true);
      final result = await middleware(handler)(context);

      expect(result.statusCode, equals(500));
      final body = jsonDecode(await result.body()) as Map<String, dynamic>;
      expect(body['status'], equals(500));
      expect(body['error'], equals('Internal server error'));
      expect(
        body['debug_message'],
        equals('Unexpected error: Invalid argument(s): Invalid argument: value must be positive'),
      );

      verify(() => logger.severe(any(), any<ArgumentError>(), any())).called(1);
    });

    test('catches Error (non-Exception) and wraps it properly', () async {
      final handler = (_) => throw StateError('Invalid state');

      final middleware = errorHandlerMiddleware();
      final result = await middleware(handler)(context);

      expect(result.statusCode, equals(500));
      final body = jsonDecode(await result.body()) as Map<String, dynamic>;
      expect(body['status'], equals(500));
      expect(body['error'], equals('Internal server error'));

      verify(() => logger.severe('Unexpected error: Bad state: Invalid state', any<StateError>(), any())).called(1);
    });

    test('preserves stack trace in logging for ApiException', () async {
      final exception = BadRequestException(message: 'Test error');
      StackTrace? capturedStackTrace;

      final testContext = _MockRequestContext();
      final testLogger = _MockLogger();
      when(() => testContext.read<Logger>()).thenReturn(testLogger);
      when(() => testLogger.warning(any(), any(), any())).thenAnswer((invocation) {
        capturedStackTrace = invocation.positionalArguments[2] as StackTrace;
      });

      final handler = (_) => throw exception;

      final middleware = errorHandlerMiddleware();
      await middleware(handler)(testContext);

      expect(capturedStackTrace, isNotNull);
      verify(() => testLogger.warning('API error: Test error', exception, capturedStackTrace)).called(1);
    });

    test('preserves stack trace in logging for generic exception', () async {
      StackTrace? capturedStackTrace;

      final testContext = _MockRequestContext();
      final testLogger = _MockLogger();
      when(() => testContext.read<Logger>()).thenReturn(testLogger);
      when(() => testLogger.severe(any(), any(), any())).thenAnswer((invocation) {
        capturedStackTrace = invocation.positionalArguments[2] as StackTrace;
      });

      final handler = (_) => throw Exception('Generic error');

      final middleware = errorHandlerMiddleware();
      await middleware(handler)(testContext);

      expect(capturedStackTrace, isNotNull);
      verify(
        () => testLogger.severe('Unexpected error: Exception: Generic error', any<Exception>(), capturedStackTrace),
      ).called(1);
    });
  });
}
