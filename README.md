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