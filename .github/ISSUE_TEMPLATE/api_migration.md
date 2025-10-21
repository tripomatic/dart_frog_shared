---
name: Migrate API to dart_frog_shared v2.2.0
about: Template for tracking migration of API projects to latest dart_frog_shared
title: 'Migrate to dart_frog_shared v2.2.0'
labels: enhancement, migration
assignees: ''
---

## Migration Goal

Migrate this API project to use `dart_frog_shared` v2.2.0+ to benefit from:
- ✅ Progressive request context enrichment with automatic field tracking
- ✅ Centralized error handling (eliminates ~20 lines per route)
- ✅ Comprehensive structured logging with SolarWinds Observability
- ✅ Automatic request body capture for error debugging
- ✅ Stack trace filtering (only 5xx errors, not 4xx)
- ✅ Deployment tracking with app_version field

## Reference Implementation

The **api_weather** project has successfully completed this migration. Review:
- [Migration Guide](https://github.com/tripomatic/dart_frog_shared/blob/main/MIGRATION_GUIDE.md)
- [api_weather middleware](https://github.com/tripomatic/api_weather/blob/main/routes/_middleware.dart)
- [api_weather route handler](https://github.com/tripomatic/api_weather/blob/main/routes/v1/weather.dart)
- [api_weather HTTP client](https://github.com/tripomatic/api_weather/blob/main/lib/clients/openweathermap_client.dart)

## Prerequisites

- [ ] Access to SolarWinds Observability API token
- [ ] Firebase project configured (if using App Check)
- [ ] Dart SDK `^3.8.0`

## Migration Checklist

### 1. Update Dependencies
- [ ] Update `pubspec.yaml` to latest `dart_frog_shared` (v2.2.0+)
- [ ] Add `logging: ^1.3.0` if not present
- [ ] Run `dart pub get`

### 2. Initialize LogHandler
- [ ] Add LogHandler initialization in `main.dart` `init()` function
- [ ] Configure SolarWinds API wrapper with correct region
- [ ] Set up developer mode for local logging
- [ ] Add `SOLARWINDS_API_TOKEN` to environment variables

### 3. Update Middleware Chain
- [ ] Review and understand middleware execution order (BACKWARDS!)
- [ ] Add `errorHandlerMiddleware` BEFORE providers (executes AFTER)
- [ ] Add `progressiveContextMiddleware` AFTER error handler in code (executes BEFORE)
- [ ] Ensure `Logger` provider is available when error handler executes
- [ ] Configure `appCheckMiddleware` (if using Firebase App Check)
- [ ] Configure `rateLimitMiddleware` with appropriate limits
- [ ] Configure `corsMiddleware`

### 4. Update Route Handlers
- [ ] Remove manual `try-catch` blocks from all route handlers
- [ ] Add `progressiveContext.capturedRequestBody = body` after reading body
- [ ] Add domain-specific fields using `progressiveContext.addField()`
- [ ] Replace manual success logging with `progressiveContext.logSuccess(logger)`
- [ ] Let `errorHandlerMiddleware` handle all exceptions automatically

### 5. Update Service/Client Layers
- [ ] Add `ProgressiveRequestContext` parameter to service methods
- [ ] Enrich context with service-level fields (cache_hit, provider, etc.)
- [ ] Pass context to HTTP clients
- [ ] Add API timing tracking with `api_response_time_ms`
- [ ] Log slow API warnings when threshold exceeded
- [ ] Log errors with context using `logger.log(Level.SEVERE, context, error)`

### 6. Environment Configuration
- [ ] Add `SOLARWINDS_API_TOKEN` to environment
- [ ] Add `ENABLE_DEV_MODE` flag
- [ ] Add Firebase variables if using App Check
- [ ] Update `.env.sample` with all required variables
- [ ] Add environment validation in `guardConfigured()`

### 7. Testing
- [ ] Run all tests: `dart test`
- [ ] Test locally with dev mode: `ENABLE_DEV_MODE=true dart_frog dev`
- [ ] Verify logs include `request_id` field
- [ ] Verify logs include custom fields from `addField()`
- [ ] Verify logs include `api_response_time_ms` from HTTP clients
- [ ] Test 400 errors → verify NO stack trace in logs
- [ ] Test 500 errors → verify stack trace IS present in logs
- [ ] Test invalid JSON → verify request body captured in error logs
- [ ] Verify success logs include all progressive context fields

### 8. Deployment
- [ ] Deploy to staging environment
- [ ] Verify SolarWinds logs appear correctly
- [ ] Verify no regressions in API functionality
- [ ] Monitor error rates and response times
- [ ] Deploy to production
- [ ] Verify production logs in SolarWinds

## Code Changes Summary

### Before (Old Pattern)
```dart
Future<Response> onRequest(RequestContext context) async {
  final logger = context.read<Logger>();
  try {
    final body = await context.request.body();
    final json = jsonDecode(body);

    final result = await service.doSomething(json);
    logger.info('Success');

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
```

### After (New Pattern)
```dart
Future<Response> onRequest(RequestContext context) async {
  final logger = context.read<Logger>();
  final service = context.read<Service>();
  final progressiveContext = context.read<ProgressiveRequestContext>();

  final body = await context.request.body();
  progressiveContext.capturedRequestBody = body;

  final json = jsonDecode(body) as Map<String, dynamic>;

  progressiveContext.addField('custom_field', json['value']);

  final result = await service.doSomething(json, progressiveContext);

  progressiveContext.logSuccess(logger);
  return Response.json(body: result);
}
// Error handling is automatic via errorHandlerMiddleware!
```

## Expected Log Output

### Success Log
```json
{
  "timestamp": "2025-10-21T10:00:00.000Z",
  "severity": "INFO",
  "message": "Request completed successfully",
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "session_hash": "abc123",
  "user_id": "firebase_uid_here",
  "method": "POST",
  "path": "/v1/endpoint",
  "status_code": 200,
  "duration_ms": 123,
  "custom_field": "value",
  "api_response_time_ms": 89,
  "cache_hit": true
}
```

### Error Log (4xx - No Stack Trace)
```json
{
  "timestamp": "2025-10-21T10:00:00.000Z",
  "severity": "WARNING",
  "message": "Bad request",
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "status_code": 400,
  "error_type": "BadRequestException",
  "error_message": "Invalid input",
  "request_body": "{\"invalid\":\"data\"}"
}
```

### Error Log (5xx - With Stack Trace)
```json
{
  "timestamp": "2025-10-21T10:00:00.000Z",
  "severity": "SEVERE",
  "message": "Internal server error",
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "status_code": 500,
  "error_type": "InternalServerErrorException",
  "error_message": "Database connection failed",
  "stack_trace": "...",
  "request_body": "{\"user\":\"data\"}"
}
```

## Common Issues & Solutions

**Issue:** Logger not found in context
**Solution:** Ensure logger provider is added AFTER error handler middleware in code

**Issue:** ProgressiveRequestContext not found
**Solution:** Ensure `progressiveContextMiddleware` is in the middleware chain

**Issue:** Middleware execution order problems
**Solution:** Remember middleware executes BACKWARDS - last `.use()` runs first!

**Issue:** Stack traces in 4xx logs
**Solution:** Upgrade to v2.2.0+ which filters stack traces for client errors

**Issue:** Request body missing from error logs
**Solution:** Add `progressiveContext.capturedRequestBody = body` immediately after reading

## Files Modified (Estimated)

- `pubspec.yaml` - Dependencies
- `main.dart` - LogHandler initialization
- `routes/_middleware.dart` - Middleware configuration
- `routes/**/*.dart` - All route handlers (remove try-catch, add context)
- `lib/services/**/*.dart` - Service methods (accept context parameter)
- `lib/clients/**/*.dart` - HTTP clients (accept and enrich context)
- `.env.sample` - Environment variables documentation

## Success Criteria

- [ ] Zero manual try-catch blocks in route handlers
- [ ] All logs include `request_id` and custom fields
- [ ] 4xx errors log without stack traces
- [ ] 5xx errors log with stack traces
- [ ] Request bodies captured in error logs
- [ ] All tests passing
- [ ] Deployed to production successfully
- [ ] SolarWinds logs verified

## Estimated Effort

- **Small API (1-3 endpoints):** 2-4 hours
- **Medium API (4-10 endpoints):** 4-8 hours
- **Large API (10+ endpoints):** 1-2 days

Time includes reading migration guide, updating code, testing, and deployment.

## Resources

- [Migration Guide](https://github.com/tripomatic/dart_frog_shared/blob/main/MIGRATION_GUIDE.md)
- [CLAUDE.md](https://github.com/tripomatic/dart_frog_shared/blob/main/CLAUDE.md)
- [api_weather Reference](https://github.com/tripomatic/api_weather)
- [dart_frog_shared v2.2.0 Release](https://github.com/tripomatic/dart_frog_shared/releases/tag/v2.2.0)

---

**Note:** This migration is recommended for all API projects to ensure consistent error handling, structured logging, and improved debugging capabilities across the platform.
