import 'package:dart_frog_shared/app_check/app_check_token_cache.dart';
import 'package:test/test.dart';

void main() {
  group('AppCheckTokenCache', () {
    late AppCheckTokenCache cache;

    setUp(() {
      cache = AppCheckTokenCache(maxSize: 3, tokenDuration: const Duration(seconds: 1));
    });

    test('should add and retrieve tokens', () {
      const token = 'valid-token';

      expect(cache.contains(token), isFalse);

      cache.add(token);

      expect(cache.contains(token), isTrue);
      expect(cache.size, equals(1));
    });

    test('should not contain expired tokens', () async {
      const token = 'expiring-token';

      cache.add(token);
      expect(cache.contains(token), isTrue);

      // Wait for token to expire
      await Future<void>.delayed(const Duration(seconds: 2));

      expect(cache.contains(token), isFalse);
      expect(cache.size, equals(0));
    });

    test('should remove oldest entries when cache is full', () async {
      // Add tokens with slight delays to ensure different timestamps
      cache.add('token1');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      cache.add('token2');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      cache.add('token3');

      expect(cache.size, equals(3));

      // Adding a 4th token should trigger cleanup
      cache.add('token4');

      // Cache removes half (1 entry with maxSize=3), then adds new one
      expect(cache.size, equals(3));
      expect(cache.contains('token4'), isTrue);
      // token1 should have been removed as it was the oldest
      expect(cache.contains('token1'), isFalse);
    });

    test('should clear all tokens', () {
      cache.add('token1');
      cache.add('token2');

      expect(cache.size, equals(2));

      cache.clear();

      expect(cache.size, equals(0));
      expect(cache.contains('token1'), isFalse);
      expect(cache.contains('token2'), isFalse);
    });

    test('should handle multiple adds of same token', () {
      const token = 'duplicate-token';

      cache.add(token);
      cache.add(token);

      expect(cache.size, equals(1));
      expect(cache.contains(token), isTrue);
    });
  });
}
