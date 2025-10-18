// ignore_for_file: prefer_const_constructors

import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_shared/exceptions/exceptions.dart';
import 'package:dart_frog_shared/logging/progressive_request_context.dart';
import 'package:dart_frog_shared/logging/strategies/request_id_strategy.dart';
import 'package:dart_frog_shared/logging/strategies/session_tracking_strategy.dart';
import 'package:dart_frog_shared/logging/strategies/user_id_strategy.dart';
import 'package:dart_frog_shared/logging/strategies/uuid_strategy.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockRequestContext extends Mock implements RequestContext {}

class _MockRequest extends Mock implements Request {}

class _MockHttpConnectionInfo extends Mock implements HttpConnectionInfo {}

class _MockRequestIdStrategy extends Mock implements RequestIdStrategy {}

class _MockSessionTrackingStrategy extends Mock implements SessionTrackingStrategy {}

class _MockUserIdStrategy extends Mock implements UserIdStrategy {}

void main() {
  group('ProgressiveRequestContext', () {
    late RequestContext mockContext;
    late Request mockRequest;
    late HttpConnectionInfo mockConnectionInfo;

    setUp(() {
      mockContext = _MockRequestContext();
      mockRequest = _MockRequest();
      mockConnectionInfo = _MockHttpConnectionInfo();

      when(() => mockContext.request).thenReturn(mockRequest);
      when(() => mockRequest.method).thenReturn(HttpMethod.get);
      when(() => mockRequest.uri).thenReturn(Uri.parse('https://example.com/test'));
      when(() => mockRequest.headers).thenReturn({});
      when(() => mockRequest.connectionInfo).thenReturn(mockConnectionInfo);
      when(() => mockConnectionInfo.remoteAddress).thenReturn(InternetAddress('192.168.1.1'));
    });

    group('constructor', () {
      test('initializes with required fields from context', () {
        final context = ProgressiveRequestContext(dartFrogContext: mockContext, requestIdStrategy: UuidStrategy());

        expect(context.requestId, isNotNull);
        expect(context.method, equals('GET'));
        expect(context.endpoint, equals('https://example.com/test'));
        expect(context.remoteAddress.address, equals('192.168.1.1'));
        expect(context.safeHeaders, isEmpty);
      });

      test('executes request ID strategy', () {
        final mockStrategy = _MockRequestIdStrategy();
        when(() => mockStrategy.generateRequestId(mockContext)).thenReturn('test-request-id');
        when(() => mockStrategy.extractTraceInfo(mockContext)).thenReturn(null);

        final context = ProgressiveRequestContext(dartFrogContext: mockContext, requestIdStrategy: mockStrategy);

        expect(context.requestId, equals('test-request-id'));
        verify(() => mockStrategy.generateRequestId(mockContext)).called(1);
      });

      test('extracts trace info from request ID strategy', () {
        final mockStrategy = _MockRequestIdStrategy();
        when(() => mockStrategy.generateRequestId(mockContext)).thenReturn('trace-123');
        when(() => mockStrategy.extractTraceInfo(mockContext)).thenReturn((traceId: 'trace-123', spanId: 'span-456'));

        final context = ProgressiveRequestContext(dartFrogContext: mockContext, requestIdStrategy: mockStrategy);

        expect(context.traceId, equals('trace-123'));
        expect(context.spanId, equals('span-456'));
      });

      test('executes session tracking strategy when provided', () {
        final mockSessionStrategy = _MockSessionTrackingStrategy();
        when(
          () => mockSessionStrategy.extractSessionInfo(mockContext),
        ).thenReturn((sessionHash: 'hash-123', clientPlatform: 'android', appId: 'app-id-123'));

        final context = ProgressiveRequestContext(
          dartFrogContext: mockContext,
          requestIdStrategy: UuidStrategy(),
          sessionStrategy: mockSessionStrategy,
        );

        expect(context.appCheckSessionHash, equals('hash-123'));
        expect(context.clientPlatform, equals('android'));
        expect(context.appCheckAppId, equals('app-id-123'));
        verify(() => mockSessionStrategy.extractSessionInfo(mockContext)).called(1);
      });

      test('executes user ID strategy when provided', () {
        final mockUserIdStrategy = _MockUserIdStrategy();
        when(() => mockUserIdStrategy.extractUserId(mockContext)).thenReturn('user-123');

        final context = ProgressiveRequestContext(
          dartFrogContext: mockContext,
          requestIdStrategy: UuidStrategy(),
          userIdStrategy: mockUserIdStrategy,
        );

        expect(context.userId, equals('user-123'));
        verify(() => mockUserIdStrategy.extractUserId(mockContext)).called(1);
      });

      test('filters headers to safe whitelist only', () {
        when(() => mockRequest.headers).thenReturn({
          'host': 'example.com',
          'authorization': 'Bearer secret-token',
          'user-agent': 'TestAgent/1.0',
          'x-custom-header': 'custom-value',
        });

        final context = ProgressiveRequestContext(dartFrogContext: mockContext, requestIdStrategy: UuidStrategy());

        expect(context.safeHeaders, containsPair('host', 'example.com'));
        expect(context.safeHeaders, containsPair('user-agent', 'TestAgent/1.0'));
        expect(context.safeHeaders, isNot(contains('authorization')));
        expect(context.safeHeaders, isNot(contains('x-custom-header')));
      });
    });

    group('addField', () {
      test('adds custom field to context', () {
        final context = ProgressiveRequestContext(dartFrogContext: mockContext, requestIdStrategy: UuidStrategy());

        context.addField('cache_hit', true);
        context.addField('provider', 'openweathermap');

        final json = context.toJson();
        expect(json['cache_hit'], equals(true));
        expect(json['provider'], equals('openweathermap'));
      });

      test('allows overriding standard fields', () {
        final context = ProgressiveRequestContext(dartFrogContext: mockContext, requestIdStrategy: UuidStrategy());

        context.addField('request_id', 'custom-id');

        final json = context.toJson();
        expect(json['request_id'], equals('custom-id'));
      });

      test('supports various data types', () {
        final context = ProgressiveRequestContext(dartFrogContext: mockContext, requestIdStrategy: UuidStrategy());

        context.addField('string', 'value');
        context.addField('int', 42);
        context.addField('double', 3.14);
        context.addField('bool', true);
        context.addField('list', [1, 2, 3]);
        context.addField('map', {'nested': 'object'});

        final json = context.toJson();
        expect(json['string'], equals('value'));
        expect(json['int'], equals(42));
        expect(json['double'], equals(3.14));
        expect(json['bool'], equals(true));
        expect(json['list'], equals([1, 2, 3]));
        expect(json['map'], equals({'nested': 'object'}));
      });
    });

    group('finalize', () {
      test('sets status code and calculates duration', () async {
        final context = ProgressiveRequestContext(dartFrogContext: mockContext, requestIdStrategy: UuidStrategy());

        await Future<void>.delayed(Duration(milliseconds: 10));
        context.finalize(statusCode: 200);

        expect(context.statusCode, equals(200));
        expect(context.durationMs, isNotNull);
        expect(context.durationMs, greaterThanOrEqualTo(10));
      });

      test('extracts error type and message from ApiException', () {
        final context = ProgressiveRequestContext(dartFrogContext: mockContext, requestIdStrategy: UuidStrategy());

        final exception = BadRequestException(message: 'Invalid input');
        context.finalize(statusCode: 400, error: exception);

        expect(context.errorType, equals('BadRequestException'));
        expect(context.errorMessage, equals('Invalid input'));
        expect(context.statusCode, equals(400));
      });

      test('uses ApiException status code if not explicitly provided', () {
        final context = ProgressiveRequestContext(dartFrogContext: mockContext, requestIdStrategy: UuidStrategy());

        final exception = UnauthorizedException(message: 'Not authorized');
        context.finalize(error: exception);

        expect(context.statusCode, equals(401));
        expect(context.errorType, equals('UnauthorizedException'));
      });

      test('handles non-ApiException errors', () {
        final context = ProgressiveRequestContext(dartFrogContext: mockContext, requestIdStrategy: UuidStrategy());

        final exception = Exception('Something went wrong');
        context.finalize(error: exception);

        expect(context.errorType, equals('_Exception'));
        expect(context.errorMessage, equals('Exception: Something went wrong'));
        expect(context.statusCode, equals(500));
      });

      test('can be called multiple times (last call wins)', () {
        final context = ProgressiveRequestContext(dartFrogContext: mockContext, requestIdStrategy: UuidStrategy());

        context.finalize(statusCode: 200);
        expect(context.statusCode, equals(200));

        context.finalize(statusCode: 500);
        expect(context.statusCode, equals(500));
      });
    });

    group('toJson', () {
      test('includes all required fields', () {
        final context = ProgressiveRequestContext(dartFrogContext: mockContext, requestIdStrategy: UuidStrategy());

        final json = context.toJson();

        expect(json['request_id'], isNotNull);
        expect(json['timestamp'], isNotNull);
        expect(json['method'], equals('GET'));
        expect(json['endpoint'], equals('https://example.com/test'));
        expect(json['remote_address'], equals('192.168.1.1'));
        expect(json['request_headers'], isA<Map>());
      });

      test('includes optional fields only when present', () {
        final mockStrategy = _MockRequestIdStrategy();
        when(() => mockStrategy.generateRequestId(mockContext)).thenReturn('trace-123');
        when(() => mockStrategy.extractTraceInfo(mockContext)).thenReturn((traceId: 'trace-123', spanId: 'span-456'));

        final context = ProgressiveRequestContext(dartFrogContext: mockContext, requestIdStrategy: mockStrategy);

        final json = context.toJson();

        expect(json['trace_id'], equals('trace-123'));
        expect(json['span_id'], equals('span-456'));
      });

      test('includes finalized fields', () {
        final context = ProgressiveRequestContext(dartFrogContext: mockContext, requestIdStrategy: UuidStrategy());

        context.finalize(statusCode: 200, error: BadRequestException(message: 'Test error'));

        final json = context.toJson();

        expect(json['status_code'], equals(200));
        expect(json['duration_ms'], isNotNull);
        expect(json['error_type'], equals('BadRequestException'));
        expect(json['error_message'], equals('Test error'));
      });

      test('includes custom fields', () {
        final context = ProgressiveRequestContext(dartFrogContext: mockContext, requestIdStrategy: UuidStrategy());

        context.addField('custom_field', 'custom_value');
        context.addField('numeric_field', 42);

        final json = context.toJson();

        expect(json['custom_field'], equals('custom_value'));
        expect(json['numeric_field'], equals(42));
      });

      test('omits null fields', () {
        final context = ProgressiveRequestContext(dartFrogContext: mockContext, requestIdStrategy: UuidStrategy());

        final json = context.toJson();

        expect(json, isNot(contains('trace_id')));
        expect(json, isNot(contains('span_id')));
        expect(json, isNot(contains('client_platform')));
        expect(json, isNot(contains('app_check_session_hash')));
        expect(json, isNot(contains('user_id')));
        expect(json, isNot(contains('status_code')));
        expect(json, isNot(contains('error_type')));
      });
    });

    group('toString', () {
      test('formats message for unfinalized context', () {
        final context = ProgressiveRequestContext(dartFrogContext: mockContext, requestIdStrategy: UuidStrategy());

        final message = context.toString();
        expect(message, equals('GET https://example.com/test'));
      });

      test('formats message for successful request', () {
        final context = ProgressiveRequestContext(dartFrogContext: mockContext, requestIdStrategy: UuidStrategy());

        context.finalize(statusCode: 200);

        final message = context.toString();
        expect(message, contains('[200]'));
        expect(message, contains('GET https://example.com/test'));
        expect(message, contains('ms)'));
      });

      test('formats message for error request', () {
        final context = ProgressiveRequestContext(dartFrogContext: mockContext, requestIdStrategy: UuidStrategy());

        context.finalize(statusCode: 400, error: BadRequestException(message: 'Invalid input'));

        final message = context.toString();
        expect(message, contains('[400]'));
        expect(message, contains('GET https://example.com/test'));
        expect(message, contains('BadRequestException'));
        expect(message, contains('Invalid input'));
      });
    });

    group('extension methods', () {
      test('logSuccess logs with INFO level', () async {
        final context = ProgressiveRequestContext(dartFrogContext: mockContext, requestIdStrategy: UuidStrategy());

        context.finalize(statusCode: 200);

        final logger = Logger('test');
        final records = <LogRecord>[];
        final subscription = logger.onRecord.listen(records.add);

        context.logSuccess(logger);

        // Allow async logging to complete
        await Future<void>.delayed(Duration(milliseconds: 10));

        expect(records, hasLength(1));
        expect(records[0].level, equals(Level.INFO));
        expect(records[0].message, equals(context.toString()));
        expect(records[0].error, isA<ProgressiveRequestContext>());

        await subscription.cancel();
      });

      test('log logs with specified level', () async {
        final context = ProgressiveRequestContext(dartFrogContext: mockContext, requestIdStrategy: UuidStrategy());

        final logger = Logger('test');
        final records = <LogRecord>[];
        final subscription = logger.onRecord.listen(records.add);

        context.log(logger, Level.WARNING, 'Custom message');

        // Allow async logging to complete
        await Future<void>.delayed(Duration(milliseconds: 10));

        expect(records, hasLength(1));
        expect(records[0].level, equals(Level.WARNING));
        expect(records[0].message, equals('Custom message'));
        expect(records[0].error, isA<ProgressiveRequestContext>());

        await subscription.cancel();
      });
    });
  });
}
