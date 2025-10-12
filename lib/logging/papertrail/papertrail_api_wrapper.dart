import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:dart_frog_shared/logging/log_api_wrapper.dart';

/// Wrapper for the Papertrail API
///
/// This class is deprecated. Use [SolarWindsApiWrapper] instead.
/// Papertrail is migrating to SolarWinds Observability.
/// See: https://documentation.solarwinds.com/en/success_center/observability/content/intro/logs/migrate-papertrail-guide.htm
@Deprecated(
  'Use SolarWindsApiWrapper instead. '
  'Papertrail is migrating to SolarWinds Observability. '
  'See: https://documentation.solarwinds.com/en/success_center/observability/content/intro/logs/migrate-papertrail-guide.htm',
)
class PapertrailApiWrapper extends LogApiWrapper {
  final String _basicAuth;
  final _logger = Logger('PapertrailApiWrapper');

  /// Track if we've already warned about authentication issues
  bool _hasWarnedAboutAuth = false;

  @Deprecated(
    'Use SolarWindsApiWrapper instead. '
    'Papertrail is migrating to SolarWinds Observability. '
    'See: https://documentation.solarwinds.com/en/success_center/observability/content/intro/logs/migrate-papertrail-guide.htm',
  )
  PapertrailApiWrapper({required String username, required String password})
    : _basicAuth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}' {
    // Warn if password is empty
    if (password.isEmpty) {
      _logger.severe('Papertrail API key is empty - logs will not be sent to Papertrail');
    }
  }

  late final _dio = Dio(
    BaseOptions(contentType: 'application/json', baseUrl: 'https://logs.collector.solarwinds.com/v1'),
  );

  /// Tracks a json with Papertrail
  @override
  Future<void> trackEvent(String body) async {
    try {
      // Send the POST request
      final response = await _dio.post(
        '/log',
        data: body,
        options: Options(contentType: 'application/json', headers: {'authorization': _basicAuth}),
      );

      // Handle the response
      if (response.statusCode != 200) {
        // Log to console for Cloud Run logs
        log(
          'Failed to send event to Papertrail. Status code: ${response.statusCode}',
          name: 'PapertrailApiWrapper',
          level: Level.SEVERE.value,
        );

        // Also log locally if this is an auth issue
        if (response.statusCode == 401 && !_hasWarnedAboutAuth) {
          _hasWarnedAboutAuth = true;
          _logger.severe('Papertrail authentication failed (401). Check PAPERTRAIL_API_KEY environment variable.');
        }
      }
    } catch (e) {
      // Always log to console for Cloud Run visibility
      log('Error sending event to Papertrail: $e', name: 'PapertrailApiWrapper', level: Level.SEVERE.value);

      // Log more details for DioErrors
      if (e is DioException) {
        log(
          'Papertrail error details - Type: ${e.type}, Message: ${e.message}, Response: ${e.response?.statusCode}',
          name: 'PapertrailApiWrapper',
          level: Level.SEVERE.value,
        );

        // Special handling for authentication errors
        if (e.response?.statusCode == 401 && !_hasWarnedAboutAuth) {
          _hasWarnedAboutAuth = true;
          _logger.severe('Papertrail authentication failed. Check PAPERTRAIL_API_KEY environment variable.');
        }
      }
    }
  }
}
