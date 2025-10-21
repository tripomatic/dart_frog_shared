# Migration Guide: Upgrade to dart_frog_shared v2.2.0

This guide helps you migrate your Dart Frog API project to use the latest version of `dart_frog_shared` (v2.2.0), which includes progressive request context enrichment, centralized error handling, and comprehensive structured logging.

## Reference Implementation

The `api_weather` project has successfully implemented all features from v2.2.0 and serves as a reference implementation. Key files to review:
- [routes/_middleware.dart](https://github.com/tripomatic/api_weather/blob/main/routes/_middleware.dart) - Middleware setup
- [routes/v1/weather.dart](https://github.com/tripomatic/api_weather/blob/main/routes/v1/weather.dart) - Route handler with progressive context
- [lib/clients/openweathermap_client.dart](https://github.com/tripomatic/api_weather/blob/main/lib/clients/openweathermap_client.dart) - HTTP client with context enrichment
- [lib/services/weather_service.dart](https://github.com/tripomatic/api_weather/blob/main/lib/services/weather_service.dart) - Service layer with context passing
- [main.dart](https://github.com/tripomatic/api_weather/blob/main/main.dart) - LogHandler initialization

## Prerequisites

- Dart SDK: `^3.8.0`
- Access to SolarWinds Observability API token
- Firebase project with App Check configured (if using App Check)

## Step 1: Update Dependencies

Update `pubspec.yaml`:

```yaml
dependencies:
  dart_frog_shared:
    git:
      url: git@github.com:tripomatic/dart_frog_shared.git
      ref: main  # Or specific version tag like v2.2.0
  logging: ^1.3.0
```

Run:
```bash
dart pub get
```

## Step 2: Initialize LogHandler in main.dart

Update your `main.dart` to initialize the `LogHandler` singleton with SolarWinds Observability:

```dart
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_shared/logging/log_handler.dart';
import 'package:dart_frog_shared/logging/solarwinds/solarwinds_api_wrapper.dart';
import 'package:logging/logging.dart';

Future<void> init(InternetAddress ip, int port) async {
  // Load environment variables (adjust to your setup)
  // ...

  // Initialize LogHandler with SolarWinds
  LogHandler.create(
    system: 'api-your-service-name',  // e.g., 'api-weather', 'api-places'
    wrapper: SolarWindsApiWrapper(
      token: Environment.instance.solarWindsApiToken,
      region: 'na-01',  // Or 'eu-01', 'na-02', 'ap-01' based on your org
    ),
    developerMode: Environment.instance.isDevMode,
  );

  // Optional: Console logging in dev mode
  if (Environment.instance.isDevMode) {
    Logger.root.onRecord.listen((record) {
      print('[${record.time}] ${record.level.name} ${record.loggerName}: ${record.message}');
      if (record.error != null) print('Error: ${record.error}');
      if (record.stackTrace != null) print('Stack trace:\n${record.stackTrace}');
    });
  }

  // Attach LogHandler to Logger
  Logger.root.onRecord.listen(logHandler);

  // Set log level
  Logger.root.level = Environment.instance.isDevMode ? Level.ALL : Level.INFO;

  final logger = Logger('main');
  logger.info('Starting up server in ${Environment.instance.isDevMode ? "debug" : "release"} mode, $ip:$port');
}
```

**Environment Variables Required:**
```bash
SOLARWINDS_API_TOKEN=your_token_here
ENABLE_DEV_MODE=false  # true for local dev
```

## Step 3: Update Middleware Chain

Replace your existing middleware setup in `routes/_middleware.dart`:

```dart
import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_shared/dart_frog_shared.dart';
import 'package:logging/logging.dart';
import 'package:shelf_enforces_ssl/shelf_enforces_ssl.dart';

Handler middleware(Handler handler) {
  final logger = Logger('api-your-service');

  // Middleware processes BACKWARDS (last added = first executed)
  var chainedHandler = handler;

  // 1. App Check (optional - if using Firebase App Check)
  chainedHandler = chainedHandler.use(
    appCheckMiddleware(
      config: AppCheckConfig(
        firebaseProjectId: Environment.instance.firebaseProjectId,
        serviceAccountJson: Environment.instance.firebaseServiceAccountJson,
        enableDevMode: Environment.instance.isDevMode,
        exemptPaths: ['/v1/ping', '/health'],
      ),
    ),
  );

  // 2. Rate limiting
  chainedHandler = chainedHandler.use(
    rateLimitMiddleware(
      config: const RateLimitConfig(
        defaultMaxRequests: 60,
        defaultWindowSize: Duration(hours: 1),
        exemptPaths: ['/v1/ping', '/health'],
      ),
    ),
  );

  // 3. CORS
  chainedHandler = chainedHandler.use(corsMiddleware());

  // 4. Error handler (MUST be before providers so it executes after)
  chainedHandler = chainedHandler.use(
    errorHandlerMiddleware(debug: Environment.instance.isDevMode),
  );

  // 5. Provide logger (MUST be after error handler so it's available)
  chainedHandler = chainedHandler.use(provider<Logger>((context) => logger));

  // 6. Your other providers (services, clients, etc.)
  // chainedHandler = chainedHandler.use(provider<YourService>(...));

  // 7. Progressive context (MUST be after error handler in code)
  chainedHandler = chainedHandler.use(
    progressiveContextMiddleware(
      requestIdStrategy: Environment.instance.isDevMode
          ? UuidStrategy()  // Dev mode: simple UUIDs
          : GCloudTraceStrategy(),  // Production: GCP trace headers
      sessionStrategy: AppCheckSessionStrategy(),  // Omit if not using App Check
      // userIdStrategy: JwtUserIdStrategy(),  // Uncomment if using Firebase Auth
    ),
  );

  // 8. Enforce SSL (first to execute, so last in chain)
  if (!Environment.instance.isDevMode) {
    chainedHandler = chainedHandler.use(fromShelfMiddleware(enforceSSL()));
  }

  return chainedHandler;
}
```

**Key Points:**
- ✅ **Order matters!** Middleware executes in reverse order
- ✅ `errorHandlerMiddleware` MUST be added BEFORE providers (executes AFTER)
- ✅ `progressiveContextMiddleware` MUST be added AFTER error handler in code (executes BEFORE at runtime)
- ✅ Logger provider MUST be available when error handler executes

## Step 4: Update Route Handlers

### Before (Old Pattern with Manual Error Handling)

```dart
Future<Response> onRequest(RequestContext context) async {
  final logger = context.read<Logger>();

  try {
    // Validate request
    final body = await context.request.body();
    final json = jsonDecode(body);

    if (json['field'] == null) {
      throw BadRequestException(message: 'Missing required field');
    }

    // Process request
    final result = await service.doSomething(json);

    // Log success manually
    logger.info('Request successful');

    return Response.json(body: result);
  } catch (e, stackTrace) {
    if (e is ApiException) {
      logger.warning('API error: ${e.message}', e, stackTrace);
      return e.toResponse();
    }
    logger.severe('Unexpected error: $e', e, stackTrace);
    return InternalServerErrorException(message: '$e').toResponse();
  }
}
```

### After (New Pattern with Progressive Context)

```dart
Future<Response> onRequest(RequestContext context) async {
  final logger = context.read<Logger>();
  final service = context.read<YourService>();
  final progressiveContext = context.read<ProgressiveRequestContext>();

  // Only allow POST
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  // Parse and validate request
  final body = await context.request.body();
  progressiveContext.capturedRequestBody = body;  // Capture for error logging

  final json = jsonDecode(body) as Map<String, dynamic>;

  if (json['field'] == null) {
    throw BadRequestException(
      message: 'Debug: Missing field parameter',  // Internal logging
      responseBodyMessage: 'Missing required field',  // User-facing message
    );
  }

  // Add domain-specific fields to context
  progressiveContext
    ..addField('user_id', json['userId'])
    ..addField('operation', 'something');

  // Process request (service can further enrich context)
  final result = await service.doSomething(json, progressiveContext);

  // Log success with full context
  progressiveContext.logSuccess(logger);

  return Response.json(body: result);
}
```

**Key Changes:**
- ❌ **Removed:** Manual `try-catch` blocks (handled by `errorHandlerMiddleware`)
- ✅ **Added:** `progressiveContext.capturedRequestBody = body` for error debugging
- ✅ **Added:** Domain-specific fields with `addField()`
- ✅ **Added:** Success logging with `logSuccess()`
- ✅ **Simplified:** Let middleware handle all error responses

## Step 5: Update Service Layer

Pass `ProgressiveRequestContext` through your service/client layers to enrich logs:

### Service Layer Example

```dart
class YourService {
  final YourClient _client;

  Future<Result> doSomething(
    Map<String, dynamic> params,
    ProgressiveRequestContext logContext,
  ) async {
    // Add service-level context
    logContext.addField('cache_hit', cacheHit);
    logContext.addField('provider', 'your-provider');

    // Pass context to client
    return _client.fetchData(params, logContext: logContext);
  }
}
```

### HTTP Client Example

```dart
class YourClient {
  final Dio _dio;
  final Logger _logger = Logger('YourClient');

  Future<Map<String, dynamic>> fetchData({
    required Map<String, dynamic> params,
    ProgressiveRequestContext? logContext,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      final response = await _dio.get('/endpoint', queryParameters: params);
      stopwatch.stop();

      // Enrich context with timing
      logContext?.addField('api_response_time_ms', stopwatch.elapsedMilliseconds);

      // Log slow API warnings
      if (stopwatch.elapsedMilliseconds >= 1000) {
        _logger.log(Level.WARNING, logContext);
      }

      return response.data;
    } on DioException catch (e) {
      stopwatch.stop();
      logContext?.addField('api_response_time_ms', stopwatch.elapsedMilliseconds);

      _logger.log(Level.SEVERE, logContext, e);

      // Convert to appropriate ApiException
      if (e.response?.statusCode == 404) {
        throw NotFoundException(message: 'Resource not found');
      }
      throw InternalServerErrorException(message: 'API error: ${e.message}');
    }
  }
}
```

## Step 6: Environment Configuration

Update your environment/config class to include required variables:

```dart
class Environment {
  // Required for SolarWinds logging
  String get solarWindsApiToken {
    return _env['SOLARWINDS_API_TOKEN'] ?? '';
  }

  // Required for App Check (if using)
  String get firebaseProjectId {
    return _env['FIREBASE_PROJECT_ID'] ?? '';
  }

  String get firebaseServiceAccountJson {
    final base64Json = _env['FIREBASE_SERVICE_ACCOUNT_JSON'] ?? '';
    if (base64Json.isEmpty) return '';
    return utf8.decode(base64.decode(base64Json));
  }

  bool get isDevMode {
    final value = _env['ENABLE_DEV_MODE'];
    return value != null && value.toLowerCase() == 'true';
  }

  void guardConfigured() {
    if (!isDevMode && !_env.isDefined('SOLARWINDS_API_TOKEN')) {
      throw StateError('SolarWinds API token is required in production');
    }
    // ... other checks
  }
}
```

## Step 7: Update .env.sample

Create/update `.env.sample` with required variables:

```bash
# Server Configuration
ENABLE_DEV_MODE=true

# SolarWinds Observability (required in production)
SOLARWINDS_API_TOKEN=your_token_here

# Firebase App Check (if using)
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_SERVICE_ACCOUNT_JSON=base64_encoded_json_here

# Your API-specific variables
# ...
```

## Step 8: Testing

1. **Run tests:**
   ```bash
   dart test
   ```

2. **Test locally with dev mode:**
   ```bash
   ENABLE_DEV_MODE=true dart_frog dev
   ```

3. **Verify logs include progressive context fields:**
   - `request_id` (UUID in dev, trace ID in prod)
   - `session_hash` (if using App Check)
   - `user_id` (if using Firebase Auth)
   - Custom fields from `addField()`
   - `api_response_time_ms` (from HTTP clients)
   - No stack traces for 4xx errors
   - Stack traces present for 5xx errors

4. **Test error scenarios:**
   - Invalid JSON → 400 with request body in logs
   - Missing required fields → 400
   - Service errors → 500 with full context

## Benefits After Migration

✅ **Reduced Boilerplate:** ~20 lines of try-catch code removed per route
✅ **Consistent Error Format:** All API exceptions return standardized JSON responses
✅ **Rich Logging:** Every log includes request_id, session, timing, custom fields
✅ **Better Debugging:** Request bodies captured in error logs, stack traces only for server errors
✅ **Deployment Tracking:** Optional app_version field to verify deployed versions
✅ **Production Ready:** SolarWinds integration, App Check, rate limiting, CORS all configured

## Common Issues

### Issue: "Logger not found in context"
**Solution:** Ensure logger provider is added AFTER error handler middleware in code (so it executes BEFORE at runtime).

### Issue: "ProgressiveRequestContext not found"
**Solution:** Ensure `progressiveContextMiddleware` is in the chain and added AFTER error handler in code.

### Issue: Middleware order causing errors
**Remember:** Middleware executes in REVERSE order. The last `.use()` call executes first!

```dart
handler
  .use(A)  // Executes THIRD
  .use(B)  // Executes SECOND
  .use(C)  // Executes FIRST
```

### Issue: Stack traces appearing in 4xx logs
**Solution:** Upgrade to v2.2.0+ which automatically excludes stack traces from warning-level (4xx) logs.

### Issue: Request body not in error logs
**Solution:** Add `progressiveContext.capturedRequestBody = body` immediately after reading the body.

## Rollback Plan

If you need to rollback:

1. Revert `pubspec.yaml` to previous `dart_frog_shared` version
2. Restore old middleware configuration
3. Restore manual try-catch in route handlers
4. Run `dart pub get`

## Support

- **Reference:** Review `api_weather` implementation
- **Documentation:** See `dart_frog_shared/CLAUDE.md`
- **Issues:** Open issue in `dart_frog_shared` repository

## Checklist

Use this checklist to track your migration:

- [ ] Updated `pubspec.yaml` to latest `dart_frog_shared`
- [ ] Initialized `LogHandler` in `main.dart`
- [ ] Configured SolarWinds API token in environment
- [ ] Updated middleware chain with proper order
- [ ] Added `progressiveContextMiddleware`
- [ ] Added `errorHandlerMiddleware`
- [ ] Removed manual try-catch from route handlers
- [ ] Added `progressiveContext.capturedRequestBody = body` in routes
- [ ] Added domain-specific fields with `addField()`
- [ ] Added success logging with `logSuccess()`
- [ ] Updated service/client layers to accept and enrich context
- [ ] Updated `.env.sample` with required variables
- [ ] Tested locally in dev mode
- [ ] Verified logs include progressive context fields
- [ ] Verified 4xx errors don't include stack traces
- [ ] Verified 5xx errors include stack traces
- [ ] Deployed to staging/production
- [ ] Verified SolarWinds logs appear correctly
