# Dart Frog Expert Memory

## Framework Overview

Dart Frog is a fast, minimalistic backend framework for Dart built on top of Shelf and inspired by frameworks like Remix, Next.js, and Express.js. It provides file-system-based routing, middleware support, and dependency injection patterns specifically designed for Flutter/Dart developers.

### Key Characteristics
- Built on Shelf HTTP server
- File-system-based routing (`routes/` directory)
- Minimal API surface with maximum productivity
- Hot reload support for development
- Production builds with Docker support
- Emphasis on type safety and Dart idioms

## Core Concepts

### 1. Handler Function Signature
```dart
typedef Handler = FutureOr<Response> Function(RequestContext context);
```
- All route handlers must return a `Response` or `Future<Response>`
- Handlers receive a `RequestContext` containing request information and dependencies
- Route parameters are passed as additional function parameters for dynamic routes

### 2. RequestContext
The `RequestContext` is the central object containing:
- `request`: The HTTP request object (headers, method, URI, body)
- Dependency injection access via `context.read<T>()`
- Connection information (remote address, etc.)

#### Common RequestContext Usage Patterns:
```dart
// Accessing request details
final method = context.request.method;
final headers = context.request.headers;
final uri = context.request.uri;

// Reading JSON body
final json = await context.request.json();

// Reading raw body
final body = await context.request.body();

// Accessing injected dependencies
final service = context.read<MyService>();
```

### 3. Middleware Architecture
Middleware in Dart Frog follows a nested function pattern:

```dart
// Basic middleware structure
Handler middleware(Handler handler) {
  return (RequestContext context) async {
    // Pre-processing logic
    
    final response = await handler(context);
    
    // Post-processing logic
    return response;
  };
}
```

#### Middleware Chaining
- Middleware is chained using the `.use()` method
- Order matters: middleware is applied in the order specified
- Each middleware wraps the next in the chain

```dart
// Correct chaining pattern
return handler
    .use(corsMiddleware())
    .use(rateLimitMiddleware())
    .use(appCheckMiddleware());
```

### 4. File System Routing
- Routes are defined by files in the `routes/` directory
- Dynamic routes use square brackets: `[id].dart`
- Nested routes follow directory structure
- Route files export an `onRequest` function
- Middleware files are named `_middleware.dart`

#### Route Examples:
```
routes/
├── index.dart              # GET /
├── users/
│   ├── index.dart          # GET /users
│   ├── [id].dart           # GET /users/:id
│   └── _middleware.dart    # Middleware for /users/*
└── _middleware.dart        # Global middleware
```

### 5. Dependency Injection with Providers
Dart Frog uses provider-based dependency injection:

```dart
// Creating a provider in middleware
Handler middleware(Handler handler) {
  return handler.use(
    provider<DatabaseService>((context) => DatabaseService()),
  );
}

// Accessing the dependency in route handlers
Response onRequest(RequestContext context) {
  final db = context.read<DatabaseService>();
  return Response.json(body: {'data': db.getData()});
}
```

## dart_frog_shared Library Analysis

### Architecture Components

#### 1. Exception Handling System
- **Base Class**: `ApiException` - all API exceptions inherit from this
- **Auto-conversion**: Exceptions automatically convert to HTTP responses via `toResponse()`
- **Dual messaging**: Internal debug messages vs. client response messages
- **JSON serialization**: All exceptions implement `JsonExportable`

```dart
// Exception usage pattern
throw BadRequestException(
  message: 'Debug info: Invalid email format', // Internal logging
  responseBodyMessage: 'Please provide a valid email' // Client response
);

// Automatic conversion to HTTP response
final response = exception.toResponse(debug: isDevelopment);
```

Available exception types:
- `BadRequestException` (400)
- `UnauthorizedException` (401)
- `AnonymousUnauthorizedException` (401 - specific for anonymous users)
- `NotFoundException` (404)
- `MethodNotAllowedException` (405)
- `ConflictException` (409)
- `InternalServerErrorException` (500)
- `DataException` (500)

#### 2. Logging Architecture
- **Singleton Pattern**: `LogHandler()` accessed via singleton
- **Papertrail Integration**: Production logging to Papertrail service
- **Developer Mode**: Local-only logging for development
- **Request Context Tracking**: Comprehensive request logging with sanitization

```dart
// LogHandler initialization
LogHandler.create(
  wrapper: PapertrailApiWrapper(
    username: 'your_username',
    password: 'your_password'
  ),
  system: 'api_name',
  developerMode: false
);

// Logging with request context
final details = ExceptionRequestContextDetails(
  context,
  await context.jsonOrBody(),
  exception
);
LogHandler().logger.severe('Request failed', details);
```

**Security Features**:
- Password obfuscation: Shows `***(length)` instead of actual passwords
- Token partial obfuscation: Shows last 8 characters with length
- Authorization header sanitization

#### 3. Request Context Extensions
The library extends `RequestContext` with helpful methods:

```dart
// ProcessRequestContextBody extension
final body = await context.jsonOrBody(); // Safely handles JSON or raw body
```

#### 4. Middleware Components

##### CORS Middleware
```dart
// Configuration
final corsConfig = CorsConfig(
  allowedOrigins: ['*'], // or specific origins
  allowedMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Firebase-AppCheck'],
  maxAge: Duration(hours: 24),
);

// Usage in _middleware.dart
Handler middleware(Handler handler) {
  return handler.use(corsMiddleware(config: corsConfig));
}
```

##### Rate Limiting Middleware
```dart
// Configuration with endpoint-specific limits
final rateLimitConfig = RateLimitConfig(
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
);
```

##### App Check Middleware (Firebase)
```dart
// Configuration
final appCheckConfig = AppCheckConfig(
  firebaseProjectId: env['FIREBASE_PROJECT_ID']!,
  serviceAccountJson: env['FIREBASE_SERVICE_ACCOUNT_JSON']!, // Raw JSON string
  enableDevMode: env['ENABLE_DEV_MODE'] == 'true',
  exemptPaths: ['/ping', '/health'],
);

// Features:
// - Token caching with configurable size and duration
// - Temporary file pattern for service account security
// - Dev mode bypass for local development
// - Comprehensive error handling and logging
```

### Key Design Patterns

#### 1. Configuration Objects
All middleware uses configuration objects with sensible defaults:
- Immutable configuration classes
- Builder-like patterns for complex configurations
- Type-safe configuration with compile-time validation

#### 2. Middleware Factory Pattern
```dart
// Middleware factories capture configuration and return middleware functions
Middleware corsMiddleware({CorsConfig config = const CorsConfig()}) {
  return (Handler handler) {
    return (RequestContext context) async {
      // Implementation using captured config
    };
  };
}
```

#### 3. Service Locator with Caching
```dart
// Token caching pattern in App Check
final tokenCache = AppCheckTokenCache(
  maxSize: config.cacheMaxSize, 
  tokenDuration: config.cacheDuration
);

// Automatic cleanup and memory management
```

#### 4. Error Context Pattern
```dart
// Rich error context for debugging
final details = ExceptionRequestContextDetails(
  context,           // Request context
  requestBody,       // Parsed request body
  exception          // The exception that occurred
);
```

## Best Practices

### 1. Middleware Ordering
```dart
// Recommended middleware order
Handler middleware(Handler handler) {
  return handler
    .use(corsMiddleware(config: corsConfig))
    .use(rateLimitMiddleware(config: rateLimitConfig))
    .use(appCheckMiddleware(config: appCheckConfig))
    .use(requestLogger())
    .use(provider<DatabaseService>((context) => DatabaseService()));
}
```

### 2. Error Handling
- Always use `ApiException` subclasses for API errors
- Separate internal debugging info from client messages
- Use structured logging with request context
- Handle async operations properly in middleware

### 3. Security Considerations
- Always sanitize sensitive data in logs
- Use App Check for client authentication when needed
- Implement rate limiting for public endpoints
- Enable CORS only for trusted origins in production

### 4. Testing Patterns
```dart
// Mock-based testing with mocktail
class _MockRequestContext extends Mock implements RequestContext {}
class _MockRequest extends Mock implements Request {}

// Setup common mocks
setUp(() {
  context = _MockRequestContext();
  request = _MockRequest();
  
  when(() => context.request).thenReturn(request);
  when(() => request.method).thenReturn(HttpMethod.get);
});
```

### 5. Development vs Production
```dart
// Environment-aware configuration
LogHandler.create(
  system: 'my_api',
  developerMode: Platform.environment['ENVIRONMENT'] != 'production',
  wrapper: PapertrailApiWrapper(/* production config */),
);
```

## Common Anti-Patterns to Avoid

1. **Incorrect Middleware Chaining**: Don't use nested `.use()` calls incorrectly
2. **Sync Middleware**: Always handle async operations properly in middleware
3. **Memory Leaks**: Properly dispose of services and connections
4. **Logging Sensitive Data**: Never log passwords or tokens without obfuscation
5. **Missing Error Context**: Always provide context when logging exceptions
6. **Hardcoded Configuration**: Use configuration objects instead of hardcoded values

## Integration Patterns

### Firebase Integration
- App Check for client authentication
- Admin SDK initialization with temporary file pattern
- Service account JSON handling (raw string, not base64)
- Automatic connection cleanup

### External Service Integration
- HTTP client patterns with proper error handling
- Retry logic for external API calls
- Circuit breaker patterns for resilience
- Connection pooling for databases

### Logging Integration
- Structured logging with JSON output
- External log aggregation (Papertrail)
- Request correlation IDs
- Performance metrics tracking

## Dart Frog Build Process Analysis

### Build Command Behavior
The `dart_frog build` command creates a production build by essentially copying the entire project directory to a `/build` folder and generating additional deployment files.

#### What Gets Copied:
- **ALL files and directories from the project root**, including:
  - Source code (`lib/`, `routes/`, `bin/`)
  - Configuration files (`pubspec.yaml`, `analysis_options.yaml`)
  - Documentation (`README.md`, etc.)
  - Hidden files (`.env`, `.secret`, `.vscode/`, etc.)
  - **Version control directories (`.git/`)** - This causes VS Code repo confusion
  - Test files (`test/` directory)
  - Build artifacts (`.dart_tool/`)

#### Generated Files:
- `Dockerfile` - For containerized deployment
- `.dockerignore` - Docker ignore rules
- `bin/server.dart` - Production server entry point

#### Build Command Options:
```bash
dart_frog build [arguments]
-h, --help            Print this usage information.
    --dart-version    The Dart SDK version used to build the Dockerfile
                      (defaults to "stable")
```

#### File Exclusion Limitations:
- **No built-in exclusion flags** - The build command doesn't provide options to exclude specific files/directories
- **No .buildignore support** - Unlike .gitignore, there's no standard build ignore mechanism
- **Copies everything** - The build process is designed to be simple and comprehensive

### Solutions for .git Directory Issue:

#### Primary Issue:
**IDE Repository Detection Problems**: When `.git` is copied to the build folder, IDEs like VS Code detect the build folder as the repository root instead of the actual project root, causing confusion with git operations and workspace management.

#### Recommended Solution - Cross-platform Build Scripts:

**For Bash/Linux/macOS (`build.sh`)**:
```bash
#!/bin/bash
set -e  # Exit on any error

echo "Building Dart Frog application..."
dart_frog build

echo "Cleaning up build directory..."
rm -rf build/.git
rm -rf build/.vscode
rm -rf build/test
rm -f build/.env  # Optional: remove local environment files

echo "Build completed successfully!"
```

**For Windows PowerShell (`build.ps1`)**:
```powershell
# Enable strict error handling
$ErrorActionPreference = "Stop"

Write-Host "Building Dart Frog application..." -ForegroundColor Green
dart_frog build

Write-Host "Cleaning up build directory..." -ForegroundColor Yellow
if (Test-Path "build\.git") { Remove-Item -Recurse -Force "build\.git" }
if (Test-Path "build\.vscode") { Remove-Item -Recurse -Force "build\.vscode" }
if (Test-Path "build\test") { Remove-Item -Recurse -Force "build\test" }
if (Test-Path "build\.env") { Remove-Item -Force "build\.env" }  # Optional

Write-Host "Build completed successfully!" -ForegroundColor Green
```

#### Alternative Solutions:

1. **One-liner with error handling**:
   ```bash
   dart_frog build && rm -rf build/.git build/.vscode build/test
   ```

2. **Project structure approach**: Keep build-sensitive directories outside the main project

3. **Docker context approach**: Use .dockerignore to exclude from Docker builds (though this doesn't solve the VS Code issue)

#### Additional Best Practices from PR #6 Review:

1. **Error Handling**: Always use `set -e` in bash scripts or `$ErrorActionPreference = "Stop"` in PowerShell for proper error handling
2. **Cross-platform Support**: Provide both bash and PowerShell scripts for broad developer support
3. **Optional .env Removal**: Removing `.env` files is optional and primarily for local builds where sensitive data shouldn't be in build artifacts
4. **.gitignore Configuration**: Consider adding `/build/` to `.gitignore` as a best practice to prevent accidental commits of build artifacts
5. **Script Permissions**: Make bash scripts executable with `chmod +x build.sh`

### Best Practices:
- Always clean up .git from build output to avoid IDE confusion
- Use cross-platform build scripts with proper error handling
- Consider removing test/ directory from production builds
- Remove development configuration (.vscode/, .env files) from builds optionally
- Add `/build/` to `.gitignore` to prevent accidental commits
- Use environment-specific configuration for production deployments

## Recent Changes and Dead-ends

### Last Updated: 2025-08-20

### Recent Changes:
- **PR #6**: Documented dart_frog build issue where .git directory is copied to build folder causing IDE repository detection problems
- Added cross-platform build scripts (bash and PowerShell) with proper error handling 
- Added CORS and rate limiting middleware (v1.8.0)
- Enhanced Firebase service account handling with temp file pattern
- Improved error context tracking and logging
- Added comprehensive test coverage for all middleware components

### Dart Frog Version Analysis:
**Version 1.2.2 (latest researched):**
- Refactored analysis options (improved code quality standards)
- Updated repository references (documentation maintenance)
- No breaking changes
- Minor version focused on maintenance and code quality

**Version 1.1.0 (current project dependency):**
- Support for reusing nested router (architectural improvement)
- Option to disable "Response buffer output" (performance optimization)
- Documentation fixes for "request" template
- No breaking changes
- Minor improvements to documentation and configuration

**Upgrade Impact Assessment (1.1.0 → 1.2.2):**
- Safe upgrade: No breaking changes identified
- Primarily maintenance and quality improvements
- Analysis options update may affect linting rules
- Repository reference updates are documentation-only changes
- Nested router reuse feature available in current version
- Response buffer output control available in current version

### Previous Dead-ends Avoided:
- Base64 encoding service account JSON (now uses raw JSON string)
- Synchronous middleware implementations (all async now)
- Memory leaks in token caching (implemented proper cleanup)
- Missing request context in error logging (now comprehensive)

### Architecture Decisions:
- Single file for all exceptions (exceptions/exceptions.dart) - keeps API surface minimal
- Provider-based dependency injection over constructor injection
- Configuration objects over builder patterns for simplicity
- Middleware factory functions over class-based middleware