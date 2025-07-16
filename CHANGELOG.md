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
