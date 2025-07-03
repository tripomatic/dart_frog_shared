import 'dart:convert';
import 'dart:developer';

import 'package:dart_frog_shared/logging/papertrail/papertrail_api_wrapper.dart';
import 'package:logging/logging.dart';
import 'package:dart_frog_shared/logging/request_context_details.dart';

/// Handles logging for the SSO server
///
/// Before using, you need to call [LogHandler.create]
class LogHandler {
  /// Singleton instance
  static late LogHandler instance;

  /// Wrapper to log to Papertrail
  final PapertrailApiWrapper wrapper;

  /// System to appear in Papertrail log, e.g. 'sso_server' or 'go_tripomatic'
  final String system;

  /// Developer mode switch
  final bool developerMode;

  LogHandler.create({required this.wrapper, required this.system, this.developerMode = false}) {
    LogHandler.instance = this;
  }

  /// Handles a log record
  Future<void> handle(LogRecord record, {bool? developerModeOverride}) async {
    final isDevMode = developerModeOverride ?? developerMode;

    final event = _createEventMap(record, isDevMode);
    final eventString = convertObjectToJson(event);

    // Log to Papertrail
    if (!isDevMode) {
      await wrapper.trackEvent(eventString);
    }

    // Print the log to the console
    log(eventString);
  }

  /// Creates an event map from a log record
  Map<String, dynamic> _createEventMap(LogRecord record, bool isDevMode) {
    final details = switch (record.object) {
      final RequestContextDetails rcd => rcd.toJson(),
      final Object o => {'object': '$o'},
      _ => null,
    };

    return {
      'system': system,
      'type': _getEventType(record),
      'logger': record.loggerName,
      'message': record.message,
      'environment': isDevMode ? 'debug' : 'release',
      if (record.error != null) 'error': record.error?.toString(),
      if (record.stackTrace != null) 'stackTrace': _reducedStackTrace(record.stackTrace!),
      ...?details,
    };
  }

  /// Gets the event type based on the log level
  String _getEventType(LogRecord record) {
    return record.level.value >= Level.SEVERE.value
        ? 'ERROR'
        : record.level == Level.WARNING
        ? 'WARNING'
        : 'INFO';
  }

  /// Sanitizes the data by replacing all objects that cannot be converted to JSON with 'ERROR' and returns a JSON string
  String convertObjectToJson(Map<String, dynamic> data) {
    final sanitizedData = data.map((key, value) => MapEntry(key, _convertValueToJson(value)));
    return jsonEncode(sanitizedData);
  }

  /// Converts a value to JSON, handling various types
  dynamic _convertValueToJson(dynamic value) {
    try {
      return switch (value) {
        final int i => i,
        final double d => d,
        final String s => s,
        final bool b => b,
        final List l => l.map((e) => _convertValueToJson(e)).toList(),
        final DateTime dt => dt.toIso8601String(),
        final Map<String, dynamic> m => m.map((key, value) => MapEntry(key, _convertValueToJson(value))),
        null => null,
        _ when value.runtimeType.toString().contains('Closure') => '[Closure]',
        _ when value.toString() == value.runtimeType.toString() => '[unable to convert to json]: $value',
        _ => '$value',
      };
    } catch (e) {
      return '[unable to convert to json]: $value';
    }
  }

  /// Reduces the stack trace to the first 8 lines
  List<String> _reducedStackTrace(StackTrace stackTrace) {
    final lines = stackTrace.toString().split('\n');
    return lines.sublist(0, 8);
  }
}

/// Global function to handle logs, using the LogHandler instance
Future<void> logHandler(LogRecord record) => LogHandler.instance.handle(record);
