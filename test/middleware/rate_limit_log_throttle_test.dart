import 'package:dart_frog_shared/middleware/rate_limit_log_throttle.dart';
import 'package:test/test.dart';

void main() {
  group('RateLimitLogThrottle', () {
    test('first hit for a key is always logged', () {
      final throttle = RateLimitLogThrottle(const Duration(minutes: 1));
      final decision = throttle.register('1.2.3.4|/v1/details');

      expect(decision.shouldLog, isTrue);
      expect(decision.suppressedCount, 0);
    });

    test('subsequent hits within window are suppressed', () {
      var now = DateTime.utc(2026, 4, 10, 12);
      final throttle = RateLimitLogThrottle(const Duration(minutes: 1), now: () => now);

      final first = throttle.register('client|path');
      expect(first.shouldLog, isTrue);

      now = now.add(const Duration(seconds: 10));
      final second = throttle.register('client|path');
      expect(second.shouldLog, isFalse);
      expect(second.suppressedCount, 0);

      now = now.add(const Duration(seconds: 20));
      final third = throttle.register('client|path');
      expect(third.shouldLog, isFalse);
    });

    test('hit after window elapses emits log with suppressed count', () {
      var now = DateTime.utc(2026, 4, 10, 12);
      final throttle = RateLimitLogThrottle(const Duration(minutes: 1), now: () => now);

      throttle.register('client|path');

      // Five suppressed hits within the window
      for (var i = 0; i < 5; i++) {
        now = now.add(const Duration(seconds: 5));
        final decision = throttle.register('client|path');
        expect(decision.shouldLog, isFalse);
      }

      // Past the window — next hit should log with count of suppressed
      now = now.add(const Duration(minutes: 1));
      final after = throttle.register('client|path');
      expect(after.shouldLog, isTrue);
      expect(after.suppressedCount, 5);
    });

    test('different keys are throttled independently', () {
      var now = DateTime.utc(2026, 4, 10, 12);
      final throttle = RateLimitLogThrottle(const Duration(minutes: 1), now: () => now);

      final a1 = throttle.register('clientA|/v1/details');
      final b1 = throttle.register('clientB|/v1/details');
      expect(a1.shouldLog, isTrue);
      expect(b1.shouldLog, isTrue);

      now = now.add(const Duration(seconds: 5));
      final a2 = throttle.register('clientA|/v1/details');
      final b2 = throttle.register('clientB|/v1/details');
      expect(a2.shouldLog, isFalse);
      expect(b2.shouldLog, isFalse);
    });

    test('zero window disables throttling', () {
      final throttle = RateLimitLogThrottle(Duration.zero);

      for (var i = 0; i < 10; i++) {
        final decision = throttle.register('client|path');
        expect(decision.shouldLog, isTrue);
        expect(decision.suppressedCount, 0);
      }
    });

    test('second emission after window resets suppressed counter', () {
      var now = DateTime.utc(2026, 4, 10, 12);
      final throttle = RateLimitLogThrottle(const Duration(minutes: 1), now: () => now);

      throttle.register('client|path');
      now = now.add(const Duration(seconds: 10));
      throttle.register('client|path');
      now = now.add(const Duration(seconds: 10));
      throttle.register('client|path');

      // Advance past window — emits with suppressedCount: 2
      now = now.add(const Duration(minutes: 1));
      final afterFirstWindow = throttle.register('client|path');
      expect(afterFirstWindow.shouldLog, isTrue);
      expect(afterFirstWindow.suppressedCount, 2);

      // No activity in the next window then one hit past it — should emit
      // with suppressedCount: 0 (counter was reset on previous emit).
      now = now.add(const Duration(minutes: 2));
      final afterSecondWindow = throttle.register('client|path');
      expect(afterSecondWindow.shouldLog, isTrue);
      expect(afterSecondWindow.suppressedCount, 0);
    });

    test('stale entries are pruned on periodic cleanup', () {
      var now = DateTime.utc(2026, 4, 10, 12);
      final throttle = RateLimitLogThrottle(const Duration(minutes: 1), now: () => now);

      throttle.register('abandoned|path');
      expect(throttle.trackedKeyCount, 1);

      // Jump well past both the cleanup interval (5 min) and the stale
      // threshold (10 * window = 10 min).
      now = now.add(const Duration(minutes: 20));
      throttle.register('active|path');

      expect(throttle.trackedKeyCount, 1);
    });
  });
}
