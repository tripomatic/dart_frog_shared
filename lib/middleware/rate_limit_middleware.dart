import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_shared/middleware/rate_limit_config.dart';
import 'package:dart_frog_shared/middleware/rate_limit_log_throttle.dart';
import 'package:dart_frog_shared/utils/constant_time_equals.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_limiter/shelf_limiter.dart';

/// Creates a rate limiting middleware with the given configuration
Middleware rateLimitMiddleware({RateLimitConfig config = const RateLimitConfig()}) {
  assert(config.serverApiKeys.every((k) => k.isNotEmpty), 'serverApiKeys must not contain empty strings');

  // Create rate limiters for each endpoint configuration
  final limiters = <String, shelf.Middleware>{};

  final clientIdentifier = config.clientIdentifierExtractor ?? RateLimitConfig.defaultClientIdentifierExtractor;
  final logThrottle = RateLimitLogThrottle(config.logThrottleDuration);

  // Create default limiter
  final defaultOptions = RateLimiterOptions(
    maxRequests: config.defaultMaxRequests,
    windowSize: config.defaultWindowSize,
    clientIdentifierExtractor: clientIdentifier,
    onRateLimitExceeded:
        config.onRateLimitExceeded ??
        (request) {
          _logRateLimitExceeded(request, clientIdentifier, logThrottle);
          return RateLimitConfig.defaultRateLimitExceededResponse(request, config.defaultMaxRequests);
        },
  );
  final defaultLimiter = shelfLimiter(defaultOptions);

  // Create endpoint-specific limiters
  for (final endpointLimit in config.endpointLimits) {
    final options = RateLimiterOptions(
      maxRequests: endpointLimit.maxRequests,
      windowSize: endpointLimit.windowSize,
      clientIdentifierExtractor: clientIdentifier,
      onRateLimitExceeded:
          config.onRateLimitExceeded ??
          (request) {
            _logRateLimitExceeded(request, clientIdentifier, logThrottle);
            return RateLimitConfig.defaultRateLimitExceededResponse(request, endpointLimit.maxRequests);
          },
    );
    limiters[endpointLimit.path] = shelfLimiter(options);
  }

  return (Handler handler) {
    return (RequestContext context) {
      // Skip rate limiting entirely in dev mode
      if (config.enableDevMode) {
        return handler(context);
      }

      final path = context.request.uri.path;
      // Normalize path by removing trailing slash for comparison (except root path)
      final normalizedPath = path.endsWith('/') && path.length > 1 ? path.substring(0, path.length - 1) : path;

      // Skip rate limiting for exempt paths
      if (config.exemptPaths.contains(normalizedPath)) {
        return handler(context);
      }

      // Skip rate limiting for OPTIONS requests
      if (context.request.method == HttpMethod.options) {
        return handler(context);
      }

      // Skip rate limiting for valid server-to-server API keys.
      // Invalid keys fall through to normal rate limiting; rejection of
      // invalid keys is handled downstream by App Check middleware.
      if (config.serverApiKeys.isNotEmpty) {
        final serverApiKey = context.request.headers['X-Server-API-Key'];
        if (serverApiKey != null && config.serverApiKeys.any((k) => constantTimeEquals(k, serverApiKey))) {
          return handler(context);
        }
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

/// Logs a "rate limit exceeded" warning, throttled per (client, path) pair.
///
/// Prevents log floods by only emitting one warning per throttle window for a
/// given client+path combination; additional blocked requests in the window
/// are counted and surfaced in the next emitted log line.
void _logRateLimitExceeded(
  shelf.Request request,
  ClientIdentifierExtractor clientIdentifier,
  RateLimitLogThrottle logThrottle,
) {
  // Use static logger name to avoid ArgumentError with paths starting with '.'
  final logger = Logger('rate_limit');
  final clientIp = clientIdentifier(request);
  final path = request.url.path;
  final key = '$clientIp|$path';

  final decision = logThrottle.register(key);
  if (!decision.shouldLog) return;

  final suppressed = decision.suppressedCount;
  if (suppressed > 0) {
    logger.warning(
      'Rate limit exceeded for IP $clientIp on $path '
      '(+$suppressed suppressed in the last ${logThrottle.window.inSeconds}s)',
    );
  } else {
    logger.warning('Rate limit exceeded for IP $clientIp on $path');
  }
}
