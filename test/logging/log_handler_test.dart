import 'package:dart_frog_shared/logging/log_handler.dart';
import 'package:dart_frog_shared/logging/papertrail/papertrail_api_wrapper.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockPapertrailApiWrapper extends Mock implements PapertrailApiWrapper {}

void main() {
  group('LogHandler', () {
    late LogHandler logHandler;
    late MockPapertrailApiWrapper mockPapertrailApiWrapper;

    setUp(() {
      mockPapertrailApiWrapper = MockPapertrailApiWrapper();
      logHandler = LogHandler.create(wrapper: mockPapertrailApiWrapper, system: 'test_system');
    });

    test('handle logs to Papertrail in release mode', () async {
      final record = LogRecord(Level.INFO, 'Test message', 'TestLogger');

      when(() => mockPapertrailApiWrapper.trackEvent(any())).thenAnswer((_) async {
        return;
      });

      await logHandler.handle(record);

      verify(() => mockPapertrailApiWrapper.trackEvent(any())).called(1);
    });

    group('convertObjectToJson', () {
      test('handles simple types correctly', () {
        final input = {'string': 'hello', 'int': 42, 'double': 3.14, 'bool': true, 'null': null};
        final result = logHandler.convertObjectToJson(input);
        expect(result, '{"string":"hello","int":42,"double":3.14,"bool":true,"null":null}');
      });

      test('handles nested objects', () {
        final input = {
          'nested': {'a': 1, 'b': 'two'},
          'list': [1, 2, 3],
        };
        final result = logHandler.convertObjectToJson(input);
        expect(result, '{"nested":{"a":1,"b":"two"},"list":[1,2,3]}');
      });

      test('handles DateTime objects', () {
        final now = DateTime.now();
        final input = {'date': now};
        final result = logHandler.convertObjectToJson(input);
        expect(result, contains('"date":"${now.toIso8601String()}"'));
      });
    });

    group('stack trace handling', () {
      test('handles empty stack trace', () async {
        final emptyStackTrace = StackTrace.fromString('');
        final record = LogRecord(Level.SEVERE, 'Error message', 'TestLogger', 'Test error', emptyStackTrace);

        when(() => mockPapertrailApiWrapper.trackEvent(any())).thenAnswer((_) async {});

        await logHandler.handle(record);

        final capturedEvent = verify(() => mockPapertrailApiWrapper.trackEvent(captureAny())).captured.first as String;
        expect(capturedEvent, contains('"stackTrace":[]'));
      });

      test('handles single line stack trace', () async {
        final singleLineStackTrace = StackTrace.fromString('#0      main (package:test/test.dart:10:5)');
        final record = LogRecord(Level.SEVERE, 'Error message', 'TestLogger', 'Test error', singleLineStackTrace);

        when(() => mockPapertrailApiWrapper.trackEvent(any())).thenAnswer((_) async {});

        await logHandler.handle(record);

        final capturedEvent = verify(() => mockPapertrailApiWrapper.trackEvent(captureAny())).captured.first as String;
        expect(capturedEvent, contains('"stackTrace":["#0      main (package:test/test.dart:10:5)"]'));
      });

      test('handles stack trace with fewer than 20 lines', () async {
        final fewLinesStackTrace = StackTrace.fromString('''
#0      main (package:test/test.dart:10:5)
#1      Object.noSuchMethod (dart:core/object.dart:100:5)
#2      Function.apply (dart:core/function.dart:50:10)
#3      runApp (package:flutter/widgets.dart:100:5)
#4      main.<anonymous> (package:app/main.dart:20:3)''');

        final record = LogRecord(Level.SEVERE, 'Error message', 'TestLogger', 'Test error', fewLinesStackTrace);

        when(() => mockPapertrailApiWrapper.trackEvent(any())).thenAnswer((_) async {});

        await logHandler.handle(record);

        final capturedEvent = verify(() => mockPapertrailApiWrapper.trackEvent(captureAny())).captured.first as String;

        // Should contain all 5 lines since it's less than 20
        expect(capturedEvent, contains('"stackTrace":['));
        expect(capturedEvent, contains('main (package:test/test.dart:10:5)'));
        expect(capturedEvent, contains('main.<anonymous> (package:app/main.dart:20:3)'));
      });

      test('handles stack trace with more than 20 lines', () async {
        // Create a stack trace with 25 lines
        final manyLinesStackTrace = StackTrace.fromString(
          List.generate(25, (i) => '#$i      method$i (package:test/file$i.dart:$i:5)').join('\n'),
        );

        final record = LogRecord(Level.SEVERE, 'Error message', 'TestLogger', 'Test error', manyLinesStackTrace);

        when(() => mockPapertrailApiWrapper.trackEvent(any())).thenAnswer((_) async {});

        await logHandler.handle(record);

        final capturedEvent = verify(() => mockPapertrailApiWrapper.trackEvent(captureAny())).captured.first as String;

        // Should be truncated to 20 lines
        expect(capturedEvent, contains('"stackTrace":['));
        expect(capturedEvent, contains('method0')); // First line
        expect(capturedEvent, contains('method19')); // 20th line
        expect(capturedEvent, isNot(contains('method20'))); // Should not contain 21st line
      });

      test('extracts error location from stack trace', () async {
        final stackTraceWithLocation = StackTrace.fromString(
          '#0      LogHandler._reducedStackTrace (package:dart_frog_shared/logging/log_handler.dart:111:18)',
        );

        final record = LogRecord(Level.SEVERE, 'Error message', 'TestLogger', 'Test error', stackTraceWithLocation);

        when(() => mockPapertrailApiWrapper.trackEvent(any())).thenAnswer((_) async {});

        await logHandler.handle(record);

        final capturedEvent = verify(() => mockPapertrailApiWrapper.trackEvent(captureAny())).captured.first as String;

        // Should extract and include error location
        expect(capturedEvent, contains('"errorLocation":"package:dart_frog_shared/logging/log_handler.dart:111:18"'));
      });

      test('handles stack trace without proper dart file location', () async {
        final stackTraceWithoutLocation = StackTrace.fromString('#0      <asynchronous suspension>');

        final record = LogRecord(Level.SEVERE, 'Error message', 'TestLogger', 'Test error', stackTraceWithoutLocation);

        when(() => mockPapertrailApiWrapper.trackEvent(any())).thenAnswer((_) async {});

        await logHandler.handle(record);

        final capturedEvent = verify(() => mockPapertrailApiWrapper.trackEvent(captureAny())).captured.first as String;

        // Should not include errorLocation when it cannot be extracted
        expect(capturedEvent, isNot(contains('"errorLocation"')));
      });
    });
  });
}
