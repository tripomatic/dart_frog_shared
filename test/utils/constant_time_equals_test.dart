import 'package:dart_frog_shared/utils/constant_time_equals.dart';
import 'package:test/test.dart';

void main() {
  group('constantTimeEquals', () {
    test('returns true for identical strings', () {
      expect(constantTimeEquals('abc123', 'abc123'), isTrue);
    });

    test('returns true for two empty strings', () {
      expect(constantTimeEquals('', ''), isTrue);
    });

    test('returns false for strings of different lengths', () {
      expect(constantTimeEquals('abc', 'abcd'), isFalse);
      expect(constantTimeEquals('abcd', 'abc'), isFalse);
    });

    test('returns false for empty vs non-empty string', () {
      expect(constantTimeEquals('', 'a'), isFalse);
      expect(constantTimeEquals('a', ''), isFalse);
    });

    test('returns false for same length strings differing in first byte', () {
      expect(constantTimeEquals('abc', 'xbc'), isFalse);
    });

    test('returns false for same length strings differing in last byte', () {
      expect(constantTimeEquals('abc', 'abx'), isFalse);
    });

    test('returns false for same length strings differing in middle byte', () {
      expect(constantTimeEquals('abc', 'axc'), isFalse);
    });

    test('handles multi-byte UTF-8 correctly', () {
      // 'é' encodes to 2 bytes in UTF-8; 'e' encodes to 1 byte.
      // Their UTF-8 byte lengths differ even though both are 1 code unit,
      // so the function must short-circuit on byte-length mismatch.
      expect(constantTimeEquals('é', 'e'), isFalse);
      expect(constantTimeEquals('café', 'café'), isTrue);
      expect(constantTimeEquals('café', 'cafe'), isFalse);
    });

    test('is case sensitive', () {
      expect(constantTimeEquals('Secret', 'secret'), isFalse);
    });
  });
}
