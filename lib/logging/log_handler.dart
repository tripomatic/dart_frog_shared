import 'dart:convert';
import 'dart:developer';

import 'package:dart_frog_shared/logging/log_api_wrapper.dart';
import 'package:dart_frog_shared/logging/progressive_request_context.dart';
import 'package:dart_frog_shared/logging/request_context_details.dart';
import 'package:logging/logging.dart';

/// Handles logging for the application
///
/// Before using, you need to call [LogHandler.create]
class LogHandler {
  /// Singleton instance
  static late LogHandler instance;

  /// Wrapper to log to external logging service
  final LogApiWrapper wrapper;

  /// System to appear in logs, e.g. 'sso_server' or 'go_tripomatic'
  final String system;

  /// Developer mode switch
  final bool developerMode;

  /// Force logging to external service even in dev mode (for testing)
  final bool forcePapertrail;

  LogHandler.create({
    required this.wrapper,
    required this.system,
    this.developerMode = false,
    this.forcePapertrail = false,
  }) {
    LogHandler.instance = this;
  }

  /// Handles a log record
  Future<void> handle(LogRecord record, {bool? developerModeOverride}) async {
    final isDevMode = developerModeOverride ?? developerMode;

    final event = _createEventMap(record, isDevMode);
    final eventString = convertObjectToJson(event);

    // Log to external service (in production mode or when forced)
    if (!isDevMode || forcePapertrail) {
      await wrapper.trackEvent(eventString);
    }

    // Print the log to the console
    log(eventString);
  }

  /// Creates an event map from a log record
  Map<String, dynamic> _createEventMap(LogRecord record, bool isDevMode) {
    final details = switch (record.object) {
      final ProgressiveRequestContext prc => prc.toJson(),
      // ignore: deprecated_member_use_from_same_package
      final RequestContextDetails rcd => rcd.toJson(),
      final Object o => {'object': '$o'},
      _ => null,
    };

    // Extract error location from stack trace if available
    final errorLocation = record.stackTrace != null ? _extractErrorLocation(record.stackTrace!) : null;

    return {
      'system': system,
      'type': _getEventType(record),
      'logger': record.loggerName,
      'message': record.message,
      'environment': isDevMode ? 'debug' : 'release',
      // Don't add error field if error is actually a context object being passed for logging
      if (record.error != null &&
          record.error is! ProgressiveRequestContext &&
          // ignore: deprecated_member_use_from_same_package
          record.error is! RequestContextDetails)
        'error': record.error?.toString(),
      if (record.stackTrace != null) 'stackTrace': _reducedStackTrace(record.stackTrace!),
      if (errorLocation != null) 'errorLocation': errorLocation,
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

  /// Reduces the stack trace to the first N lines (configurable)
  List<String> _reducedStackTrace(StackTrace stackTrace) {
    final stackTraceString = stackTrace.toString();
    // Handle empty stack traces
    if (stackTraceString.isEmpty) {
      return [];
    }

    final lines = stackTraceString.split('\n');
    // Filter out empty lines that might result from split
    final nonEmptyLines = lines.where((line) => line.isNotEmpty).toList();

    if (nonEmptyLines.isEmpty) {
      return [];
    }

    // Increase from 8 to 20 lines to capture more context
    // First few lines usually contain the actual error location
    const maxLines = 20;
    return nonEmptyLines.sublist(0, nonEmptyLines.length < maxLines ? nonEmptyLines.length : maxLines);
  }

  /// Extracts the error location (file and line) from the first line of the stack trace
  String? _extractErrorLocation(StackTrace stackTrace) {
    try {
      final lines = stackTrace.toString().split('\n');
      if (lines.isEmpty) return null;

      // First line typically contains the error location
      // Format: #0      ClassName.methodName (package:project/path/file.dart:line:column)
      final firstLine = lines[0];
      final match = RegExp(r'\(([^)]+\.dart:[0-9]+:[0-9]+)\)').firstMatch(firstLine);

      if (match != null) {
        return match.group(1); // Returns something like "package:api_places/services/place_service.dart:123:45"
      }

      // Fallback: try to find any .dart file reference in the first few lines
      for (final line in lines.take(3)) {
        final fileMatch = RegExp(r'([\w/]+\.dart:[0-9]+:[0-9]+)').firstMatch(line);
        if (fileMatch != null) {
          return fileMatch.group(1);
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }
}

/// Global function to handle logs, using the LogHandler instance
Future<void> logHandler(LogRecord record) => LogHandler.instance.handle(record);
