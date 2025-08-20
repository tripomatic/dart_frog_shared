/// In-memory cache for validated App Check tokens
class AppCheckTokenCache {
  /// Creates a new token cache instance
  AppCheckTokenCache({required this.maxSize, required this.tokenDuration});

  /// Maximum number of tokens to cache
  final int maxSize;

  /// How long tokens remain valid
  final Duration tokenDuration;

  final _cache = <String, DateTime>{};

  /// Checks if a token exists in the cache and is still valid
  bool contains(String token) {
    final expirationTime = _cache[token];
    if (expirationTime == null) {
      return false;
    }

    if (DateTime.now().isAfter(expirationTime)) {
      _cache.remove(token);
      return false;
    }

    return true;
  }

  /// Adds a token to the cache
  void add(String token) {
    // Clean up if cache is at capacity
    if (_cache.length >= maxSize && !_cache.containsKey(token)) {
      _removeOldestEntries();
    }

    _cache[token] = DateTime.now().add(tokenDuration);
  }

  /// Removes the oldest entries to make room for new ones
  void _removeOldestEntries() {
    // Sort entries by expiration time and remove the oldest half
    final sortedEntries = _cache.entries.toList()..sort((a, b) => a.value.compareTo(b.value));

    // Remove at least half, but ensure we make room for the new entry
    final entriesToRemoveCount = (maxSize ~/ 2).clamp(1, _cache.length);
    final entriesToRemove = sortedEntries.take(entriesToRemoveCount);
    for (final entry in entriesToRemove) {
      _cache.remove(entry.key);
    }
  }

  /// Clears all cached tokens
  void clear() {
    _cache.clear();
  }

  /// Gets the current number of cached tokens
  int get size => _cache.length;
}
