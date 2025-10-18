## 2.0.1

- Fixed bug where ProgressiveRequestContext objects were incorrectly appearing in the 'error' field of JSON logs for successful requests
- Updated LogHandler to filter out context objects from the error field when logging via extension methods

## 2.0.0

- **BREAKING CHANGE**: Added progressive request context enrichment system for enhanced structured logging
- Added `ProgressiveRequestContext` class that progressively enriches request context with metadata
- Added pluggable strategy pattern for flexible context extraction:
  - `RequestIdStrategy` interface for request ID generation
  - `GCloudTraceStrategy` for Google Cloud Run distributed tracing integration (with UUID fallback)
  - `UuidStrategy` for UUID-based request IDs
  - `SessionTrackingStrategy` interface for session tracking
  - `AppCheckSessionStrategy` for Firebase App Check session correlation via MD5 hash
  - `UserIdStrategy` interface for user identification
  - `JwtUserIdStrategy` for extracting Firebase UID from JWT tokens
- Added `progressiveContextMiddleware` for automatic context injection
- Enhanced `errorHandlerMiddleware` to use `ProgressiveRequestContext` for rich error logging
- Updated `ExceptionRequestContextDetails` to extend `ProgressiveRequestContext`
  - Added backward-compatible factory method `fromException()`
  - Private constructor now uses `UuidStrategy` by default
- Deprecated `RequestContextDetails` base class (use `ProgressiveRequestContext` instead)
- Removed `ResponseRequestContextDetails` (not used)
- Fixed `LogHandler` to properly recognize and serialize `ProgressiveRequestContext`
- Added `crypto` (^3.0.6) and `uuid` (^4.5.1) dependencies
- Added comprehensive documentation and usage examples in CLAUDE.md

### Migration Guide

**Before (v1.x):**
```dart
Handler middleware(Handler handler) {
  return handler
    .use(provider<Logger>((_) => logger))
    .use(errorHandlerMiddleware(debug: isDev));
}

// In routes - manual context creation
final details = ExceptionRequestContextDetails(context, await context.jsonOrBody(), e);
```

**After (v2.x):**
```dart
Handler middleware(Handler handler) {
  return handler
    .use(provider<Logger>((_) => logger))
    .use(progressiveContextMiddleware(
      requestIdStrategy: GCloudTraceStrategy(), // or UuidStrategy()
      sessionStrategy: AppCheckSessionStrategy(),
      userIdStrategy: JwtUserIdStrategy(),
    ))
    .use(errorHandlerMiddleware(debug: isDev));
}

// In routes - use factory method for backward compatibility
final details = ExceptionRequestContextDetails.fromException(context, await context.jsonOrBody(), e);

// Or access progressive context directly
final progressiveContext = context.read<ProgressiveRequestContext>();
progressiveContext.addField('cache_hit', true);
progressiveContext.logSuccess(logger);
```

## 1.9.1

- Improved documentation to clarify that `region` parameter must match your SolarWinds organization's data center
- Added guidance on how to find your organization's region from the SolarWinds URL
- Updated code documentation in `SolarWindsApiWrapper` constructor
- Clarified that European deployments should use `eu-01` region

## 1.9.0

- Added SolarWinds Observability API support with Bearer token authentication
- Added abstract `LogApiWrapper` base class for polymorphic logging service support
- Added `SolarWindsApiWrapper` with regional endpoint support (eu-01, na-01, na-02, ap-01)
- Deprecated `PapertrailApiWrapper` (still fully supported, no breaking changes)
- Updated `LogHandler` to use base class for polymorphism
- Replaced `print()` with `log()` from `dart:developer` for proper structured logging
- Fixed static mutable state - now uses instance variables for thread safety
- Added comprehensive documentation for migration from Papertrail to SolarWinds Observability
- Added release process documentation

## 1.8.2

- Fixed critical RangeError crash in `LogHandler._reducedStackTrace` when handling short stack traces
- Improved stack trace handling with increased line limit from 8 to 20 for better debugging
- Added error location extraction from stack traces for cleaner logs
- Added `forcePapertrail` option to force Papertrail logging even in developer mode
- Improved Papertrail logging configuration
- Removed legacy commands and agents code

## 1.8.1

- Added prominent documentation in README about dart_frog build .git directory issue
- Provided build script solution to prevent IDE repository detection problems
- Updated dependencies and fixed analyzer issues
- Updated dart_frog_expert agent memory with build process analysis

## 1.8.0

- Added CORS middleware with configurable options
  - `CorsConfig` for customizing allowed origins, methods, headers, and max age
  - `corsMiddleware` function for easy integration with Dart Frog
  - Automatic handling of OPTIONS preflight requests
- Added rate limiting middleware with flexible configuration
  - `RateLimitConfig` for default and endpoint-specific rate limits
  - `EndpointRateLimit` for custom limits per endpoint
  - Support for exempt paths and custom client identifier extraction
  - Configurable rate limit exceeded responses
  - `rateLimitMiddleware` function for easy integration with Dart Frog
- Added `shelf` and `shelf_limiter` dependencies
- Added comprehensive tests for both middleware components

## 1.7.0

- **BREAKING CHANGE**: `AppCheckConfig.serviceAccountJson` now accepts raw JSON string instead of base64 encoded string
- Updated `FirebaseAppCheckService` to use raw JSON directly, removing base64 decoding
- Updated documentation and examples to reflect the new API
- This change simplifies the integration by removing the need for base64 encoding

## 1.6.0

- Added Firebase App Check middleware for API protection
- Added `AppCheckConfig` for configuring App Check behavior
- Added `AppCheckTokenCache` for performance optimization
- Added `FirebaseAppCheckService` for Firebase integration
- Added `appCheckMiddleware` function for easy integration with Dart Frog
- Added `dart_firebase_admin` dependency

## 1.5.0

- Added `NotFoundException` (404) exception
- Added `ConflictException` (409) exception
- Added exports to main library file for easier imports

## 1.4.0

- Added `InternalServerErrorException`
- SDK and lint upgrade
- Improved obfuscation by showing lengths or absence of password

## 1.0.0

- Initial version.
