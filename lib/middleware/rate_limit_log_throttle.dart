/// In-memory throttle state for rate-limit log warnings.
///
/// Tracks, per key (typically a `"client|path"` pair), when the last warning
/// was emitted and how many blocked requests have been suppressed since
/// then. Stale entries are pruned opportunistically to keep memory bounded.
///
/// This class is internal to the rate limit middleware but is exposed so it
/// can be unit-tested directly.
class RateLimitLogThrottle {
  /// Creates a log throttle with the given [window].
  ///
  /// A [window] of [Duration.zero] disables throttling — every call to
  /// [register] returns `shouldLog: true`.
  RateLimitLogThrottle(this.window, {DateTime Function()? now}) : _now = now ?? DateTime.now {
    _lastCleanup = _now();
  }

  /// Minimum time between emitted log entries for the same key.
  final Duration window;
  final DateTime Function() _now;
  final Map<String, _ThrottleEntry> _entries = {};
  late DateTime _lastCleanup;

  /// Number of tracked keys. Exposed for testing and diagnostics.
  int get trackedKeyCount => _entries.length;

  /// Registers a rate-limit hit for [key] and decides whether it should be
  /// logged. When a log is emitted, the returned `suppressedCount` reflects
  /// how many hits were absorbed silently since the previous emission.
  RateLimitLogDecision register(String key) {
    final now = _now();
    _maybeCleanup(now);

    if (window == Duration.zero) {
      return const RateLimitLogDecision(shouldLog: true, suppressedCount: 0);
    }

    final entry = _entries[key];
    if (entry == null || now.difference(entry.lastLoggedAt) >= window) {
      final suppressed = entry?.suppressedCount ?? 0;
      _entries[key] = _ThrottleEntry(lastLoggedAt: now, suppressedCount: 0);
      return RateLimitLogDecision(shouldLog: true, suppressedCount: suppressed);
    }

    entry.suppressedCount++;
    return const RateLimitLogDecision(shouldLog: false, suppressedCount: 0);
  }

  void _maybeCleanup(DateTime now) {
    // Sweep at most every 5 minutes to keep the map bounded without paying
    // the cost on every call.
    if (now.difference(_lastCleanup) < const Duration(minutes: 5)) return;
    _lastCleanup = now;

    // Drop entries older than 10x the window — they represent clients that
    // have stopped probing and no longer need tracking.
    final staleThreshold = window * 10;
    _entries.removeWhere((_, entry) => now.difference(entry.lastLoggedAt) > staleThreshold);
  }
}

/// Outcome of a [RateLimitLogThrottle.register] call.
class RateLimitLogDecision {
  /// Creates a throttle decision.
  const RateLimitLogDecision({required this.shouldLog, required this.suppressedCount});

  /// Whether the caller should emit a log entry.
  final bool shouldLog;

  /// When [shouldLog] is `true`, how many blocked hits were suppressed since
  /// the previous emitted log entry for this key. Always `0` when
  /// [shouldLog] is `false`.
  final int suppressedCount;
}

class _ThrottleEntry {
  _ThrottleEntry({required this.lastLoggedAt, required this.suppressedCount});

  DateTime lastLoggedAt;
  int suppressedCount;
}
