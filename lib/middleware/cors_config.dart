/// Configuration for CORS middleware
class CorsConfig {
  /// Creates a new CORS configuration
  const CorsConfig({
    this.allowedOrigins = const ['*'],
    this.allowedMethods = const ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    this.allowedHeaders = const [
      'Origin',
      'Content-Type',
      'Accept',
      'Authorization',
      'X-Requested-With',
      'X-Firebase-AppCheck',
    ],
    this.maxAge = const Duration(hours: 24),
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
