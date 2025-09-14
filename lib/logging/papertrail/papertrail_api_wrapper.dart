// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:logging/logging.dart';

/// Wrapper for the Papertrail API
class PapertrailApiWrapper {
  final String _basicAuth;
  final _logger = Logger('PapertrailApiWrapper');

  /// Track if we've already warned about authentication issues
  static bool _hasWarnedAboutAuth = false;

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
        print('Failed to send event to Papertrail. Status code: ${response.statusCode}');

        // Also log locally if this is an auth issue
        if (response.statusCode == 401 && !_hasWarnedAboutAuth) {
          _hasWarnedAboutAuth = true;
          _logger.severe('Papertrail authentication failed (401). Check PAPERTRAIL_API_KEY environment variable.');
        }
      }
    } catch (e) {
      // Always log to console for Cloud Run visibility
      print('Error sending event to Papertrail: $e');

      // Log more details for DioErrors
      if (e is DioException) {
        print('Papertrail error details - Type: ${e.type}, Message: ${e.message}, Response: ${e.response?.statusCode}');

        // Special handling for authentication errors
        if (e.response?.statusCode == 401 && !_hasWarnedAboutAuth) {
          _hasWarnedAboutAuth = true;
          _logger.severe('Papertrail authentication failed. Check PAPERTRAIL_API_KEY environment variable.');
        }
      }
    }
  }
}
