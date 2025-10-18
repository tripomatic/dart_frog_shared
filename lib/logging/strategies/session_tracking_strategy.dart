import 'package:dart_frog/dart_frog.dart';

/// Strategy for extracting session tracking information from requests.
///
/// Implementations can extract session identifiers, client platform information,
/// and application identifiers from request headers or tokens.
abstract class SessionTrackingStrategy {
  /// Extract session tracking information from the request.
  ///
  /// Returns a record with:
  /// - `sessionHash`: A hash or identifier for correlating requests in the same session
  /// - `clientPlatform`: Platform identifier (e.g., "android", "ios", "web")
  /// - `appId`: Application identifier
  ///
  /// All fields are optional and may be `null` if not available.
  ({String? sessionHash, String? clientPlatform, String? appId}) extractSessionInfo(RequestContext context);
}
