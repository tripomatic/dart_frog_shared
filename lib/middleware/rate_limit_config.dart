import 'dart:io';

import 'package:shelf/shelf.dart' as shelf;

/// Function to extract client identifier from a request
typedef ClientIdentifierExtractor = String Function(shelf.Request request);

/// Configuration for rate limiting on a specific endpoint
class EndpointRateLimit {
  /// Creates a rate limit configuration for an endpoint
  const EndpointRateLimit({required this.path, required this.maxRequests, this.windowSize = const Duration(hours: 1)});

  /// The endpoint path to apply this rate limit to
  final String path;

  /// Maximum number of requests allowed in the window
  final int maxRequests;

  /// Time window for rate limiting
  final Duration windowSize;
}

/// Configuration for rate limiting middleware
class RateLimitConfig {
  /// Creates a rate limiting configuration
  const RateLimitConfig({
    this.enableDevMode = false,
    this.defaultMaxRequests = 60,
    this.defaultWindowSize = const Duration(hours: 1),
    this.endpointLimits = const [],
    this.exemptPaths = const [],
    this.clientIdentifierExtractor,
    this.onRateLimitExceeded,
  });

  /// Enable development mode to bypass all rate limiting
  final bool enableDevMode;

  /// Default maximum requests for endpoints without specific limits
  final int defaultMaxRequests;

  /// Default time window for rate limiting
  final Duration defaultWindowSize;

  /// Endpoint-specific rate limits
  final List<EndpointRateLimit> endpointLimits;

  /// Paths that are exempt from rate limiting
  final List<String> exemptPaths;

  /// Custom function to extract client identifier
  final ClientIdentifierExtractor? clientIdentifierExtractor;

  /// Custom handler for rate limit exceeded
  final shelf.Response Function(shelf.Request)? onRateLimitExceeded;

  /// Default client identifier extractor that uses IP address
  static String defaultClientIdentifierExtractor(shelf.Request request) {
    // Check X-Forwarded-For header first (Cloud Run)
    final xForwardedFor = request.headers['x-forwarded-for'];
    if (xForwardedFor != null && xForwardedFor.isNotEmpty) {
      // X-Forwarded-For can contain multiple IPs, take the first one
      return xForwardedFor.split(',').first.trim();
    }

    // Fall back to connection info
    final connectionInfo = request.context['shelf.io.connection_info'] as HttpConnectionInfo?;
    return connectionInfo?.remoteAddress.address ?? 'unknown';
  }

  /// Default rate limit exceeded response
  static shelf.Response defaultRateLimitExceededResponse(shelf.Request request, int maxRequests) {
    return shelf.Response(
      429,
      body: '{"error": "Rate limit exceeded. Maximum $maxRequests requests per hour allowed."}',
      headers: {'content-type': 'application/json'},
    );
  }
}
