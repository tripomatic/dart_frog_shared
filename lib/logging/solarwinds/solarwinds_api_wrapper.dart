import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:logging/logging.dart';
import 'package:dart_frog_shared/logging/log_api_wrapper.dart';

/// Wrapper for the SolarWinds Observability API
///
/// This is the recommended implementation for logging to SolarWinds Observability.
/// It uses Bearer token authentication and supports regional endpoints.
class SolarWindsApiWrapper extends LogApiWrapper {
  final String _bearerToken;
  final _logger = Logger('SolarWindsApiWrapper');

  /// Track if we've already warned about authentication issues
  bool _hasWarnedAboutAuth = false;

  /// Creates a SolarWinds API wrapper
  ///
  /// [token] - API ingestion token from SolarWinds Observability settings
  /// [region] - Data center region (e.g., 'eu-01', 'na-01', 'na-02', 'ap-01')
  ///
  /// Example:
  /// ```dart
  /// final wrapper = SolarWindsApiWrapper(
  ///   token: 'your-api-token',
  ///   region: 'eu-01',
  /// );
  /// ```
  SolarWindsApiWrapper({required String token, required String region}) : _bearerToken = 'Bearer $token' {
    // Warn if token is empty
    if (token.isEmpty) {
      _logger.severe('SolarWinds API token is empty - logs will not be sent to SolarWinds');
    }

    // Initialize Dio with regional endpoint
    _dio = Dio(
      BaseOptions(
        contentType: 'application/octet-stream',
        baseUrl: 'https://logs.collector.$region.cloud.solarwinds.com/v1',
      ),
    );
  }

  late final Dio _dio;

  /// Tracks a json event with SolarWinds Observability
  @override
  Future<void> trackEvent(String body) async {
    try {
      // Send the POST request
      final response = await _dio.post(
        '/logs',
        data: body,
        options: Options(contentType: 'application/octet-stream', headers: {'Authorization': _bearerToken}),
      );

      // Handle the response
      if (response.statusCode != 200) {
        // Log to console for Cloud Run logs
        log(
          'Failed to send event to SolarWinds. Status code: ${response.statusCode}',
          name: 'SolarWindsApiWrapper',
          level: Level.SEVERE.value,
        );

        // Also log locally if this is an auth issue
        if (response.statusCode == 401 && !_hasWarnedAboutAuth) {
          _hasWarnedAboutAuth = true;
          _logger.severe('SolarWinds authentication failed (401). Check SOLARWINDS_API_TOKEN environment variable.');
        }
      }
    } catch (e) {
      // Always log to console for Cloud Run visibility
      log('Error sending event to SolarWinds: $e', name: 'SolarWindsApiWrapper', level: Level.SEVERE.value);

      // Log more details for DioErrors
      if (e is DioException) {
        log(
          'SolarWinds error details - Type: ${e.type}, Message: ${e.message}, Response: ${e.response?.statusCode}',
          name: 'SolarWindsApiWrapper',
          level: Level.SEVERE.value,
        );

        // Special handling for authentication errors
        if (e.response?.statusCode == 401 && !_hasWarnedAboutAuth) {
          _hasWarnedAboutAuth = true;
          _logger.severe('SolarWinds authentication failed. Check SOLARWINDS_API_TOKEN environment variable.');
        }
      }
    }
  }
}
