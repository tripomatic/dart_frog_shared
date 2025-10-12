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
