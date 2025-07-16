# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

dart_frog_shared is an experimental Dart library that provides shared exception handling and logging infrastructure for Dart Frog server projects. It standardizes API error responses and centralizes logging with Papertrail integration.

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
- Request context tracking through `RequestContextDetails` hierarchy
- Automatic sanitization of sensitive data (passwords show as `***(length)`, tokens partially obfuscated)
- Papertrail integration for production, developer mode for local-only logging

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
```dart
LogHandler.create(
  wrapper: PapertrailApiWrapper(
    username: 'your_username',
    password: 'your_password'
  ),
  system: 'api_name',
  developerMode: false // Set true for local development
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

## Important Notes
- This is a shared library - changes affect multiple Dart Frog projects
- Maintain backward compatibility when adding features
- Password obfuscation is critical for security - never log raw passwords
- The `lint: ^2.8.0` package enforces strict Dart analysis rules
- Version follows semantic versioning (currently 1.5.0)