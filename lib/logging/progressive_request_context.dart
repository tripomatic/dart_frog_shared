import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_shared/exceptions/exceptions.dart';
import 'package:dart_frog_shared/logging/strategies/request_id_strategy.dart';
import 'package:dart_frog_shared/logging/strategies/session_tracking_strategy.dart';
import 'package:dart_frog_shared/logging/strategies/user_id_strategy.dart';
import 'package:logging/logging.dart';

/// Progressive request context for structured logging with pluggable strategies.
///
/// This context object is created at the start of a request and progressively
/// enriched as the request is processed. It provides automatic extraction of
/// request metadata via strategies and supports custom fields for domain-specific data.
///
/// Usage:
/// ```dart
/// // Create with strategies
/// final context = ProgressiveRequestContext(
///   dartFrogContext: context,
///   requestIdStrategy: GCloudTraceStrategy(),
///   sessionStrategy: AppCheckSessionStrategy(),
///   userIdStrategy: JwtUserIdStrategy(),
/// );
///
/// // Add custom fields during processing
/// context.addField('cache_hit', true);
/// context.addField('provider', 'openweathermap');
///
/// // Finalize and log
/// context.finalize(statusCode: 200);
/// logger.info(context);  // Uses toString() and toJson()
/// ```
class ProgressiveRequestContext {
  /// The Dart Frog request context
  final RequestContext dartFrogContext;

  /// Time when the request started processing
  final DateTime startTime;

  // Auto-populated fields via strategies
  /// Unique request identifier
  late final String requestId;

  /// HTTP request method
  late final String method;

  /// Request endpoint path
  late final String endpoint;

  /// Distributed tracing trace ID (if available)
  String? traceId;

  /// Distributed tracing span ID (if available)
  String? spanId;

  /// Remote client address
  late final InternetAddress remoteAddress;

  /// Safe headers that can be logged (filtered whitelist)
  late final Map<String, String> safeHeaders;

  // Optional fields from strategies
  /// Client platform (e.g., "android", "ios", "web")
  String? clientPlatform;

  /// Session hash for correlating requests across APIs
  String? appCheckSessionHash;

  /// Full App Check application identifier
  String? appCheckAppId;

  /// User identifier (Firebase UID)
  String? userId;

  // Custom fields (extensible)
  final Map<String, dynamic> _customFields = {};

  // Request body (for error debugging)
  /// Raw request body (optional, for debugging failed requests)
  String? requestBody;

  // Response tracking
  /// HTTP response status code
  int? statusCode;

  /// Request duration in milliseconds
  int? durationMs;

  // Error tracking
  /// Type of error that occurred
  String? errorType;

  /// Error message
  String? errorMessage;

  /// The error object itself
  Object? errorObject;

  /// Whitelisted safe headers to log
  static const Set<String> _safeHeadersToLog = {'user-agent', 'host', 'x-forwarded-for', 'x-cloud-trace-context'};

  /// Creates a new progressive request context with the given strategies.
  ///
  /// The [requestIdStrategy] is required and determines how request IDs are generated.
  /// The [sessionStrategy] and [userIdStrategy] are optional and can be null to disable
  /// session/user tracking.
  ///
  /// Strategies execute immediately in the constructor to extract context information.
  ProgressiveRequestContext({
    required this.dartFrogContext,
    required RequestIdStrategy requestIdStrategy,
    SessionTrackingStrategy? sessionStrategy,
    UserIdStrategy? userIdStrategy,
  }) : startTime = DateTime.now() {
    // Execute request ID strategy
    requestId = requestIdStrategy.generateRequestId(dartFrogContext);
    final traceInfo = requestIdStrategy.extractTraceInfo(dartFrogContext);
    traceId = traceInfo?.traceId;
    spanId = traceInfo?.spanId;

    // Execute session tracking strategy (if provided)
    if (sessionStrategy != null) {
      final sessionInfo = sessionStrategy.extractSessionInfo(dartFrogContext);
      appCheckSessionHash = sessionInfo.sessionHash;
      clientPlatform = sessionInfo.clientPlatform;
      appCheckAppId = sessionInfo.appId;
    }

    // Execute user ID strategy (if provided)
    if (userIdStrategy != null) {
      userId = userIdStrategy.extractUserId(dartFrogContext);
    }

    // Auto-populate basic request information
    method = dartFrogContext.request.method.name.toUpperCase();
    endpoint = dartFrogContext.request.uri.toString();
    remoteAddress = dartFrogContext.request.connectionInfo.remoteAddress;
    safeHeaders = _extractSafeHeaders(dartFrogContext);
  }

  /// Extracts safe headers from the request that can be logged.
  Map<String, String> _extractSafeHeaders(RequestContext context) {
    final headers = context.request.headers;
    final safeHeadersMap = <String, String>{};

    for (final key in headers.keys) {
      if (_safeHeadersToLog.contains(key.toLowerCase())) {
        safeHeadersMap[key] = headers[key]!;
      }
    }

    return safeHeadersMap;
  }

  /// Adds a custom field to the context.
  ///
  /// Use this to add domain-specific information that should be included in logs.
  ///
  /// **Standard field names** (automatically populated, do not override):
  /// - `request_id` - Unique request identifier
  /// - `timestamp` - Request start time
  /// - `method` - HTTP method (GET, POST, etc.)
  /// - `endpoint` - Request path
  /// - `remote_address` - Client IP address
  /// - `request_headers` - Safe headers (whitelisted)
  /// - `trace_id` - Distributed tracing trace ID
  /// - `span_id` - Distributed tracing span ID
  /// - `client_platform` - Platform (android/ios/web)
  /// - `app_check_session_hash` - App Check session hash
  /// - `app_check_app_id` - Full App Check app ID
  /// - `user_id` - Firebase user ID
  /// - `status_code` - HTTP response status
  /// - `duration_ms` - Request duration
  /// - `error_type` - Error class name
  /// - `error_message` - Error description
  ///
  /// Example:
  /// ```dart
  /// context.addField('cache_hit', true);
  /// context.addField('provider', 'openweathermap');
  /// context.addField('api_response_time_ms', 245);
  /// ```
  ///
  /// Note: Custom fields with the same name as standard fields will override
  /// the standard values in the JSON output.
  void addField(String key, dynamic value) {
    _customFields[key] = value;
  }

  /// Gets the captured raw request body.
  String? get capturedRequestBody => requestBody;

  /// Captures the raw request body for error debugging.
  ///
  /// Set this early in request processing (before parsing) to ensure
  /// the raw body is available in error logs if parsing fails.
  ///
  /// Example:
  /// ```dart
  /// final body = await request.body();
  /// progressiveContext.capturedRequestBody = body;
  /// final json = jsonDecode(body);  // If this fails, we have the raw body in logs
  /// ```
  set capturedRequestBody(String? body) {
    requestBody = body;
  }

  /// Finalizes the context with response or error information.
  ///
  /// Call this at the end of request processing to set the final status code,
  /// duration, and error details (if any).
  ///
  /// Example:
  /// ```dart
  /// // Success
  /// context.finalize(statusCode: 200);
  ///
  /// // Error
  /// context.finalize(statusCode: 500, error: exception);
  /// ```
  void finalize({int? statusCode, Object? error}) {
    this.statusCode = statusCode;
    durationMs = DateTime.now().difference(startTime).inMilliseconds;

    if (error != null) {
      errorObject = error;
      // Get the error type directly from the object's runtime type
      errorType = error.runtimeType.toString();

      if (error is ApiException) {
        errorMessage = error.message;
        // Use ApiException status code if statusCode not explicitly provided
        this.statusCode ??= error.statusCode;
      } else {
        errorMessage = error.toString();
        this.statusCode ??= 500;
      }
    }
  }

  /// Converts the context to a JSON object for structured logging.
  ///
  /// Only non-null fields are included in the output.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'request_id': requestId,
      'timestamp': startTime.toIso8601String(),
      'method': method,
      'endpoint': endpoint,
      'remote_address': remoteAddress.address,
      'request_headers': safeHeaders,
    };

    // Add optional tracing fields
    if (traceId != null) json['trace_id'] = traceId;
    if (spanId != null) json['span_id'] = spanId;

    // Add optional session/user fields
    if (clientPlatform != null) json['client_platform'] = clientPlatform;
    if (appCheckSessionHash != null) {
      json['app_check_session_hash'] = appCheckSessionHash;
    }
    if (appCheckAppId != null) json['app_check_app_id'] = appCheckAppId;
    if (userId != null) json['user_id'] = userId;

    // Add custom fields
    json.addAll(_customFields);

    // Add request body (for error debugging)
    if (requestBody != null) json['request_body'] = requestBody;

    // Add response/error fields
    if (statusCode != null) json['status_code'] = statusCode;
    if (durationMs != null) json['duration_ms'] = durationMs;
    if (errorType != null) json['error_type'] = errorType;
    if (errorMessage != null) json['error_message'] = errorMessage;

    return json;
  }

  @override
  String toString() {
    // Provide meaningful message based on context state
    if (errorType != null) {
      return '[$statusCode] $method $endpoint - $errorType: $errorMessage';
    }
    if (statusCode != null && durationMs != null) {
      return '[$statusCode] $method $endpoint (${durationMs}ms)';
    }
    return '$method $endpoint';
  }
}

/// Extension methods for logging with ProgressiveRequestContext.
extension ProgressiveRequestContextLogging on ProgressiveRequestContext {
  /// Log successful request with INFO level.
  ///
  /// Automatically finalizes the context if not already finalized.
  ///
  /// Usage:
  /// ```dart
  /// final context = context.read<ProgressiveRequestContext>();
  /// context.addField('cache_hit', true);
  /// context.logSuccess(logger);  // Logs with full context
  /// ```
  void logSuccess(Logger logger, {int statusCode = 200}) {
    if (this.statusCode == null) {
      finalize(statusCode: statusCode);
    }
    // Pass context as message (not error) so LogHandler can extract it from record.object
    // The logger will call toString() on the context to generate the log message
    logger.info(this);
  }

  /// Log error with WARNING (4xx) or SEVERE (5xx) level.
  ///
  /// Automatically finalizes the context with error details if not already finalized.
  /// Uses WARNING for client errors (400-499) and SEVERE for server errors (500+).
  ///
  /// Usage:
  /// ```dart
  /// try {
  ///   // Process request
  /// } catch (e, stackTrace) {
  ///   progressiveContext.logError(logger, e, stackTrace);
  ///   rethrow;
  /// }
  /// ```
  void logError(Logger logger, Object error, StackTrace stackTrace, {int? statusCode}) {
    // Determine status code from error if not provided
    final finalStatusCode = statusCode ?? (error is ApiException ? error.statusCode : 500);

    if (this.statusCode == null) {
      finalize(statusCode: finalStatusCode, error: error);
    }

    // Log with appropriate level based on status code
    // Pass context as message so LogHandler can extract it from record.object
    if (finalStatusCode >= 500) {
      logger.severe(this, error, stackTrace);
    } else {
      logger.warning(this, error, stackTrace);
    }
  }

  /// Log with custom level and message.
  ///
  /// For custom logging scenarios, pass the context as the message parameter.
  /// Do not use this for success logging - use logSuccess() instead.
  ///
  /// Usage:
  /// ```dart
  /// context.log(logger, Level.WARNING);  // Uses toString() for message
  /// ```
  void log(Logger logger, Level level) {
    logger.log(level, this);
  }
}
