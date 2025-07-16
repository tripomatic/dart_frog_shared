# dart_frog_shared

An experimental library with some Dart logging / exception handling code shared between Dart Frog projects.

## Features

### Exception Handling

The library provides a comprehensive set of API exceptions that can be easily converted to Dart Frog responses:

- `BadRequestException` (400) - For invalid requests
- `UnauthorizedException` (401) - For unauthorized access
- `AnonymousUnauthorizedException` (401) - Specific unauthorized exception for anonymous users
- `NotFoundException` (404) - For resources that cannot be found
- `MethodNotAllowedException` (405) - For unsupported HTTP methods
- `ConflictException` (409) - For conflicts with current state
- `InternalServerErrorException` (500) - For internal server errors
- `DataException` (500) - For data-related errors

### Logging

Provides a centralized logging system with Papertrail integration:

- `LogHandler` - Singleton for managing application logs
- Support for developer mode (local logging only)
- Request context tracking
- JSON-formatted log events

### App Check

Firebase App Check integration for protecting your APIs from abuse:

- `appCheckMiddleware` - Ready-to-use middleware for Dart Frog applications
- Token caching for improved performance
- Configurable exempt paths (e.g., `/ping`, `/health`)
- Developer mode support for local development
- Automatic token validation with Firebase Admin SDK

## Usage

### Exception Handling

```dart
import 'package:dart_frog_shared/dart_frog_shared.dart';

// In your route handler
Response onRequest(RequestContext context) {
  try {
    // Your logic here
  } catch (e) {
    throw BadRequestException(
      message: 'Invalid input: $e',
      responseBodyMessage: 'Please check your input and try again',
    );
  }
}
```

### Logging

```dart
import 'package:dart_frog_shared/dart_frog_shared.dart';

// Initialize the logger (typically in your main function)
LogHandler.create(
  wrapper: PapertrailApiWrapper(
    username: 'your_username',
    password: 'your_password',
  ),
  system: 'my_api',
  developerMode: false,
);

// Use the logger
final logger = Logger('MyRoute');
logger.info('Processing request');
```

### App Check

```dart
import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_shared/dart_frog_shared.dart';

// In your _middleware.dart file
Handler middleware(Handler handler) {
  return handler
    .use(requestLogger())
    .use(appCheckMiddleware(
      config: AppCheckConfig(
        firebaseProjectId: 'your-project-id',
        serviceAccountJson: serviceAccountJsonString,
        enableDevMode: false,
        exemptPaths: ['/ping', '/health'],
        cacheMaxSize: 1000,
        cacheDuration: const Duration(hours: 1),
      ),
    ));
}
```

#### Configuration

The App Check middleware requires the following configuration:

- `firebaseProjectId`: Your Firebase project ID
- `serviceAccountJson`: Firebase service account JSON as a string
- `enableDevMode`: Set to `true` to bypass App Check in development
- `exemptPaths`: List of paths that don't require App Check validation
- `cacheMaxSize`: Maximum number of tokens to cache (default: 1000)
- `cacheDuration`: How long to cache validated tokens (default: 1 hour)

#### Environment Variables

For production use, it's recommended to store sensitive configuration in environment variables:

```bash
export FIREBASE_PROJECT_ID="your-project-id"
export FIREBASE_SERVICE_ACCOUNT_JSON='{"type": "service_account", "project_id": "your-project"}'
export ENABLE_DEV_MODE="false"
```

Then use them in your middleware:

```dart
Handler middleware(Handler handler) {
  return handler
    .use(appCheckMiddleware(
      config: AppCheckConfig(
        firebaseProjectId: Platform.environment['FIREBASE_PROJECT_ID']!,
        serviceAccountJson: Platform.environment['FIREBASE_SERVICE_ACCOUNT_JSON']!,
        enableDevMode: Platform.environment['ENABLE_DEV_MODE'] == 'true',
        exemptPaths: ['/ping', '/health'],
      ),
    ));
}