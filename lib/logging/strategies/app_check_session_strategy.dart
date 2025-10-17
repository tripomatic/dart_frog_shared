import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_shared/logging/strategies/session_tracking_strategy.dart';

/// Session tracking strategy that extracts information from Firebase App Check tokens.
///
/// Extracts three pieces of information from the App Check JWT token:
/// 1. **Session Hash**: MD5 hash of the full token for cross-API session correlation
/// 2. **Client Platform**: Platform identifier ("android", "ios", "web") from the app ID
/// 3. **App ID**: Full application identifier from the JWT's `sub` claim
///
/// The session hash enables tracking user sessions across multiple API calls
/// without storing sensitive tokens. Since App Check tokens are short-lived
/// (~1 hour) but reused across API calls, the hash provides a good approximation
/// of a user session (~5 minutes of activity).
///
/// Example App ID format: `1:123456789:android:abc123def456`
class AppCheckSessionStrategy implements SessionTrackingStrategy {
  /// Header name for Firebase App Check token
  static const String _appCheckHeader = 'X-Firebase-AppCheck';

  @override
  ({String? sessionHash, String? clientPlatform, String? appId}) extractSessionInfo(RequestContext context) {
    final appCheckToken = context.request.headers[_appCheckHeader];

    if (appCheckToken == null || appCheckToken.isEmpty) {
      return (sessionHash: null, clientPlatform: null, appId: null);
    }

    // Compute MD5 hash of the full token for session correlation
    final sessionHash = md5.convert(utf8.encode(appCheckToken)).toString();

    // Decode JWT to extract app ID (without verification - just for extraction)
    String? appId;
    String? clientPlatform;

    try {
      final parts = appCheckToken.split('.');
      if (parts.length == 3) {
        // Decode payload (second part)
        final payload =
            jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))) as Map<String, dynamic>;

        // Extract app ID from 'sub' claim
        appId = payload['sub'] as String?;

        // Extract platform from app ID format: "1:123:android:abc" -> "android"
        if (appId != null) {
          final platformMatch = RegExp(':(android|ios|web):').firstMatch(appId);
          if (platformMatch != null) {
            clientPlatform = platformMatch.group(1);
          }
        }
      }
    } catch (_) {
      // Ignore decode errors - token will be verified by App Check middleware
      // We just return the session hash without app ID/platform
    }

    return (sessionHash: sessionHash, clientPlatform: clientPlatform, appId: appId);
  }
}
