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
  });
}
