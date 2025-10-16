# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

dart_frog_shared is an experimental Dart library that provides shared exception handling and logging infrastructure for Dart Frog server projects. It standardizes API error responses and centralizes logging with support for SolarWinds Observability and legacy Papertrail.

## Development Commands

```bash
# Install dependencies
dart pub get

# Run all tests
dart test

# Run a specific test file
dart test test/logging/log_handler_test.dart

# Analyze code (lint)
dart analyze

# Format code
dart format .

# Check formatting without applying changes
dart format --set-exit-if-changed .
```

## Architecture Patterns

### Exception Handling System
- All API exceptions inherit from `ApiException` base class
- Each exception automatically converts to appropriate HTTP response via `toResponse()`
- Factory constructors allow custom response messages while maintaining internal debug messages
- Exceptions implement `JsonExportable` for clean JSON serialization

### Logging Architecture
- `LogHandler` uses singleton pattern - access via `LogHandler()` not constructor
- Polymorphic logging service support via `LogApiWrapper` abstract base class
- `SolarWindsApiWrapper` - Modern Bearer token authentication for SolarWinds Observability (recommended)
- `PapertrailApiWrapper` - Legacy Basic Auth for Papertrail (deprecated)
- Request context tracking through `RequestContextDetails` hierarchy
- Automatic sanitization of sensitive data (passwords show as `***(length)`, tokens partially obfuscated)
- Developer mode for local-only logging

### App Check Architecture
- `appCheckMiddleware` creates middleware function with captured config and services
- `AppCheckTokenCache` provides in-memory caching with automatic cleanup
- `FirebaseAppCheckService` handles Firebase Admin SDK initialization with temp file pattern
- Token verification is async and cached for performance
- Middleware integrates cleanly with Dart Frog's middleware chain

### Key Design Decisions
- Extension method `ProcessRequestContextBody` adds body processing to Dart Frog's `RequestContext`
- All exceptions are in `lib/exceptions/exceptions.dart` (single file by design)
- Logging components are modularized under `lib/logging/`
- Stack traces are automatically reduced to 5 lines for readability

## Usage Patterns

### Creating Custom Exceptions
```dart
throw BadRequestException(
  message: 'Debug info: Invalid email format', // Internal logging
  responseBodyMessage: 'Please provide a valid email' // Client response
);
```

### Setting Up Logging

**SolarWinds Observability (Recommended):**
```dart
LogHandler.create(
  wrapper: SolarWindsApiWrapper(
    token: env['SOLARWINDS_API_TOKEN']!,
    region: 'eu-01', // Must match your organization's region (eu-01, na-01, na-02, ap-01)
  ),
  system: 'api_name',
  developerMode: false // Set true for local development
);
```

**Note:** The `region` parameter must match your SolarWinds Observability organization's data center. Find your region in the SolarWinds URL: `https://my.XX-YY.cloud.solarwinds.com` (XX-YY is your region). European deployments should use `eu-01`.

**Legacy Papertrail (Deprecated):**
```dart
LogHandler.create(
  wrapper: PapertrailApiWrapper(
    username: env['PAPERTRAIL_USERNAME']!,
    password: env['PAPERTRAIL_PASSWORD']!,
  ),
  system: 'api_name',
  developerMode: false
);
```

### Logging Requests
```dart
final details = ExceptionRequestContextDetails(
  context,
  await context.jsonOrBody(),
  exception
);
LogHandler().logger.severe('Request failed', details);
```

### Configuring App Check
```dart
// In _middleware.dart
Handler middleware(Handler handler) {
  return handler
    .use(appCheckMiddleware(
      config: AppCheckConfig(
        firebaseProjectId: env['FIREBASE_PROJECT_ID']!,
        serviceAccountJson: env['FIREBASE_SERVICE_ACCOUNT_JSON']!, // Raw JSON string
        enableDevMode: env['ENABLE_DEV_MODE'] == 'true',
        exemptPaths: ['/ping', '/health'],
      ),
    ));
}
```

## Testing Approach
- Uses `mocktail` for mocking dependencies
- Test files mirror source structure under `test/`
- Focus on testing public API and edge cases
- Mock external dependencies (Papertrail API, HTTP clients)

## Middleware Components

### CORS Middleware
The library provides configurable CORS (Cross-Origin Resource Sharing) middleware:

```dart
// In _middleware.dart
Handler middleware(Handler handler) {
  return handler
    .use(corsMiddleware(
      config: CorsConfig(
        allowedOrigins: ['*'], // Or specific origins
        allowedMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
        allowedHeaders: ['Content-Type', 'Authorization', 'X-Firebase-AppCheck'],
        maxAge: Duration(hours: 24),
      ),
    ));
}
```

### Rate Limiting Middleware
Configurable rate limiting with endpoint-specific limits:

```dart
// In _middleware.dart
Handler middleware(Handler handler) {
  return handler
    .use(rateLimitMiddleware(
      config: RateLimitConfig(
        defaultMaxRequests: 60,
        defaultWindowSize: Duration(hours: 1),
        endpointLimits: [
          EndpointRateLimit(
            path: '/autocomplete',
            maxRequests: 300,
            windowSize: Duration(hours: 1),
          ),
        ],
        exemptPaths: ['/ping', '/health'],
        clientIdentifierExtractor: (request) => extractClientIp(request),
        onRateLimitExceeded: (request) => customRateLimitResponse(request),
      ),
    ));
}
```

### Error Handler Middleware
Centralized exception handling that automatically converts ApiExceptions to JSON responses:

```dart
// In _middleware.dart
Handler middleware(Handler handler) {
  final logger = Logger('MyApi');

  return handler
    .use(provider<Logger>((_) => logger))
    .use(errorHandlerMiddleware(debug: env['DEBUG_MODE'] == 'true'))
    .use(corsMiddleware(config: corsConfig))
    .use(rateLimitMiddleware(config: rateLimitConfig));
}
```

**Benefits:**
- Eliminates ~20 lines of try-catch boilerplate per route
- Ensures consistent error response format across all endpoints
- Automatically logs all errors with appropriate severity levels
- Supports debug mode to include internal error details

**Route handlers become much simpler:**

```dart
// BEFORE (without error handler middleware)
Future<Response> onRequest(RequestContext context) async {
  final logger = context.read<Logger>();
  try {
    if (invalidInput) {
      throw BadRequestException(message: 'Invalid input');
    }
    return Response.json(body: result);
  } catch (e, stackTrace) {
    if (e is ApiException) {
      logger.warning('Error: ${e.message}', e, stackTrace);
      return e.toResponse();
    }
    logger.severe('Unexpected: $e', e, stackTrace);
    return InternalServerErrorException(message: '$e').toResponse();
  }
}

// AFTER (with error handler middleware)
Future<Response> onRequest(RequestContext context) async {
  if (invalidInput) {
    throw BadRequestException(message: 'Invalid input');
  }
  return Response.json(body: result);
}
// Middleware automatically catches and converts exceptions!
```

**Custom error handling is still possible:**

```dart
Future<Response> onRequest(RequestContext context) async {
  try {
    return await specialOperation();
  } on SpecificException catch (e) {
    // Custom handling for this specific exception
    return Response.json(body: {'custom': 'response'});
  }
  // All other exceptions caught by middleware
}
```

## Important Notes
- This is a shared library - changes affect multiple Dart Frog projects
- Maintain backward compatibility when adding features
- Password obfuscation is critical for security - never log raw passwords
- The `lint: ^2.8.0` package enforces strict Dart analysis rules
- Version follows semantic versioning (currently 1.8.0)