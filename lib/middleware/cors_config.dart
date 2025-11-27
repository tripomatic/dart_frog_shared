/// Configuration for CORS middleware
class CorsConfig {
  /// Default allowed origins for CORS requests.
  static const List<String> defaultAllowedOrigins = ['*'];

  /// Default allowed HTTP methods for CORS requests.
  static const List<String> defaultAllowedMethods = ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'];

  /// Default allowed headers in CORS requests.
  static const List<String> defaultAllowedHeaders = [
    'Origin',
    'Content-Type',
    'Accept',
    'Authorization',
    'X-Requested-With',
    'X-Firebase-AppCheck',
  ];

  /// Default max age for preflight request caching.
  static const Duration defaultMaxAge = Duration(hours: 24);

  /// Creates a new CORS configuration
  const CorsConfig({
    this.allowedOrigins = defaultAllowedOrigins,
    this.allowedMethods = defaultAllowedMethods,
    this.allowedHeaders = defaultAllowedHeaders,
    this.maxAge = defaultMaxAge,
  });

  /// Allowed origins for CORS requests
  final List<String> allowedOrigins;

  /// Allowed HTTP methods
  final List<String> allowedMethods;

  /// Allowed headers in requests
  final List<String> allowedHeaders;

  /// Max age for preflight request caching
  final Duration maxAge;

  /// Converts allowed origins to header value
  String get allowedOriginsHeader {
    return allowedOrigins.join(', ');
  }

  /// Converts allowed methods to header value
  String get allowedMethodsHeader {
    return allowedMethods.join(', ');
  }

  /// Converts allowed headers to header value
  String get allowedHeadersHeader {
    return allowedHeaders.join(', ');
  }

  /// Converts max age to header value
  String get maxAgeHeader {
    return maxAge.inSeconds.toString();
  }
}
