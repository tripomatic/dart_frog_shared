import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_shared/middleware/rate_limit_config.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_limiter/shelf_limiter.dart';

/// Creates a rate limiting middleware with the given configuration
Middleware rateLimitMiddleware({RateLimitConfig config = const RateLimitConfig()}) {
  // Create rate limiters for each endpoint configuration
  final limiters = <String, shelf.Middleware>{};

  // Create default limiter
  final defaultOptions = RateLimiterOptions(
    maxRequests: config.defaultMaxRequests,
    windowSize: config.defaultWindowSize,
    clientIdentifierExtractor: config.clientIdentifierExtractor ?? RateLimitConfig.defaultClientIdentifierExtractor,
    onRateLimitExceeded:
        config.onRateLimitExceeded ??
        (request) {
          final logger = Logger(request.url.path);
          final clientIdentifier = config.clientIdentifierExtractor ?? RateLimitConfig.defaultClientIdentifierExtractor;
          final clientIp = clientIdentifier(request);
          logger.warning('Rate limit exceeded for IP $clientIp on ${request.url.path}');

          return RateLimitConfig.defaultRateLimitExceededResponse(request, config.defaultMaxRequests);
        },
  );
  final defaultLimiter = shelfLimiter(defaultOptions);

  // Create endpoint-specific limiters
  for (final endpointLimit in config.endpointLimits) {
    final options = RateLimiterOptions(
      maxRequests: endpointLimit.maxRequests,
      windowSize: endpointLimit.windowSize,
      clientIdentifierExtractor: config.clientIdentifierExtractor ?? RateLimitConfig.defaultClientIdentifierExtractor,
      onRateLimitExceeded:
          config.onRateLimitExceeded ??
          (request) {
            final logger = Logger(request.url.path);
            final clientIdentifier =
                config.clientIdentifierExtractor ?? RateLimitConfig.defaultClientIdentifierExtractor;
            final clientIp = clientIdentifier(request);
            logger.warning('Rate limit exceeded for IP $clientIp on ${request.url.path}');

            return RateLimitConfig.defaultRateLimitExceededResponse(request, endpointLimit.maxRequests);
          },
    );
    limiters[endpointLimit.path] = shelfLimiter(options);
  }

  return (Handler handler) {
    return (RequestContext context) {
      final path = context.request.uri.path;

      // Skip rate limiting for exempt paths
      if (config.exemptPaths.contains(path)) {
        return handler(context);
      }

      // Skip rate limiting for OPTIONS requests
      if (context.request.method == HttpMethod.options) {
        return handler(context);
      }

      // Apply appropriate rate limiter based on endpoint
      Handler rateLimitedHandler;
      if (limiters.containsKey(path)) {
        // Use endpoint-specific limiter
        rateLimitedHandler = fromShelfMiddleware(limiters[path]!)(handler);
      } else {
        // Use default limiter
        rateLimitedHandler = fromShelfMiddleware(defaultLimiter)(handler);
      }

      return rateLimitedHandler(context);
    };
  };
}
