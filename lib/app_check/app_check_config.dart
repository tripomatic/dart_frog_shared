/// Configuration for App Check middleware
class AppCheckConfig {
  /// Creates an App Check configuration
  const AppCheckConfig({
    required this.firebaseProjectId,
    required this.serviceAccountJson,
    this.enableDevMode = false,
    this.exemptPaths = const [],
    this.serverApiKeys = const [],
    this.cacheMaxSize = 1000,
    this.cacheDuration = const Duration(hours: 1),
  });

  /// Firebase project ID
  final String firebaseProjectId;

  /// Firebase service account JSON as a string
  final String serviceAccountJson;

  /// Whether to bypass App Check in development mode
  final bool enableDevMode;

  /// Paths that are exempt from App Check validation
  final List<String> exemptPaths;

  /// Pre-shared API keys for server-to-server authentication.
  ///
  /// When a request includes a valid `X-Server-API-Key` header matching
  /// one of these keys, App Check validation is bypassed.
  ///
  /// Each calling service should have its own key for auditability.
  /// Keys are typically stored as a comma-separated string in environment
  /// variables / GCP Secret Manager and split at the configuration boundary.
  final List<String> serverApiKeys;

  /// Maximum number of tokens to cache
  final int cacheMaxSize;

  /// How long to cache validated tokens
  final Duration cacheDuration;
}
