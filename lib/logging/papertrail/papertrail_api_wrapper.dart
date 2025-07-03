// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:dio/dio.dart';

/// Wrapper for the Papertrail API
class PapertrailApiWrapper {
  final String _basicAuth;

  PapertrailApiWrapper({required String username, required String password})
    : _basicAuth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';

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
        print('Failed to send event to Papertrail. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending event to Papertrail: $e');
    }
  }
}
