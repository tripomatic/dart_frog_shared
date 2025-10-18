import 'package:dart_frog/dart_frog.dart';

/// Strategy for extracting user IDs from requests.
///
/// Implementations can extract user identifiers from authentication tokens,
/// headers, or other sources in the request.
abstract class UserIdStrategy {
  /// Extract user ID from the request.
  ///
  /// Returns the user identifier if available, or `null` if the user
  /// is not authenticated or the ID cannot be extracted.
  String? extractUserId(RequestContext context);
}
