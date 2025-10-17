import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_shared/logging/strategies/user_id_strategy.dart';

/// User ID strategy that extracts Firebase UID from JWT tokens.
///
/// Extracts the user ID from the `sub` claim of a Firebase Auth JWT token
/// in the `Authorization: Bearer <token>` header.
///
/// **SECURITY WARNING**: This strategy decodes and extracts information from
/// JWTs WITHOUT signature verification. It is designed ONLY for logging purposes
/// and MUST be used in combination with proper authentication middleware that
/// verifies the JWT signature.
///
/// **NEVER rely on unverified JWT data for authorization decisions.**
///
/// Proper middleware order:
/// ```dart
/// Handler middleware(Handler handler) {
///   return handler
///     .use(firebaseAuthMiddleware())  // Verifies JWT signature first
///     .use(progressiveContextMiddleware(
///       userIdStrategy: JwtUserIdStrategy(),  // Safe to extract after verification
///     ))
///     .use(errorHandlerMiddleware());
/// }
/// ```
///
/// The Firebase UID is not considered PII and is safe to log in protected
/// log systems for debugging and user-specific issue tracking.
class JwtUserIdStrategy implements UserIdStrategy {
  /// Header name for authorization
  static const String _authorizationHeader = 'authorization';

  @override
  String? extractUserId(RequestContext context) {
    final authHeader = context.request.headers[_authorizationHeader];

    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return null;
    }

    final token = authHeader.substring(7); // Remove "Bearer " prefix

    // Check if it's a JWT (3 parts separated by dots)
    final parts = token.split('.');
    if (parts.length != 3) {
      return null;
    }

    try {
      // Decode payload (second part) without verification
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))) as Map<String, dynamic>;

      // Extract Firebase UID from 'sub' claim
      return payload['sub'] as String?;
    } catch (_) {
      // Ignore decode errors - token might be invalid or not a JWT
      return null;
    }
  }
}
