/// Configuration for App Check middleware
class AppCheckConfig {
  /// Creates an App Check configuration
  const AppCheckConfig({
    required this.firebaseProjectId,
    required this.serviceAccountJson,
    this.enableDevMode = false,
    this.exemptPaths = const [],
    this.cacheMaxSize = 1000,
    this.cacheDuration = const Duration(hours: 1),
  });

  /// Firebase project ID
  final String firebaseProjectId;

  /// Base64 encoded Firebase service account JSON
  final String serviceAccountJson;

  /// Whether to bypass App Check in development mode
  final bool enableDevMode;

  /// Paths that are exempt from App Check validation
  final List<String> exemptPaths;

  /// Maximum number of tokens to cache
  final int cacheMaxSize;

  /// How long to cache validated tokens
  final Duration cacheDuration;
}
