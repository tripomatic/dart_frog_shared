import 'dart:io';
import 'dart:math';

import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_shared/exceptions/json_exportable.dart';
import 'package:dart_frog_shared/logging/progressive_request_context.dart';
import 'package:dart_frog_shared/logging/strategies/uuid_strategy.dart';

/// Base class for request details
///
/// @deprecated Use [ProgressiveRequestContext] instead.
/// This class is kept for backward compatibility only.
///
/// See implementation: [ExceptionRequestContextDetails]
@Deprecated('Use ProgressiveRequestContext instead')
abstract class RequestContextDetails {
  /// Request context
  final RequestContext context;

  /// Request body
  final dynamic requestBody;

  @Deprecated('Use ProgressiveRequestContext instead')
  RequestContextDetails(this.context, this.requestBody);

  /// Request endpoint
  Uri get endpoint => context.request.uri;

  /// Whitelisted safe headers to log
  static const Set<String> _safeHeadersToLog = {'user-agent', 'host', 'x-forwarded-for', 'x-cloud-trace-context'};

  /// Request headers (filtered to only include safe headers)
  Map<String, String> get requestHeaders {
    final headers = context.request.headers;
    final safeHeadersMap = <String, String>{};

    for (final key in headers.keys) {
      if (_safeHeadersToLog.contains(key.toLowerCase())) {
        safeHeadersMap[key] = headers[key]!;
      }
    }

    return safeHeadersMap;
  }

  /// Remote address
  InternetAddress get remoteAddress => context.request.connectionInfo.remoteAddress;

  /// Request method
  HttpMethod get requestMethod => context.request.method;

  @override
  String toString() => '$requestMethod $endpoint';

  /// Converts the request context details to a JSON object
  Map<String, dynamic> toJson() => {
    'method': requestMethod.toString(),
    'endpoint': endpoint.toString(),
    'request_body': obfuscateUserData(requestBody),
    'remote_address': remoteAddress.address,
    'request_headers': requestHeaders,
  };

  /// Obfuscates the user data in the request body (password field)
  static dynamic obfuscateUserData(dynamic request) {
    if (request case final Map<String, dynamic> r) {
      final obfuscated = <String, dynamic>{};
      for (final key in request.keys) {
        if (key.toLowerCase() == 'password') {
          final content = '${r[key]}';
          obfuscated[key] = (request[key] is String && content.isNotEmpty) ? '***(${content.length})' : request[key];
        } else if (key.toLowerCase() == 'authorization') {
          final content = '${r[key]}';
          final last8 = content.substring(max(0, content.length - 8));
          obfuscated[key] = content.startsWith('Bearer ')
              ? 'Bearer ***$last8(${content.length})'
              : '***$last8(${content.length})';
        } else if (key.toLowerCase() == 'id_token') {
          final content = '${r[key]}';
          final last8 = content.substring(max(0, content.length - 8));
          obfuscated[key] = '***$last8(${content.length})';
        } else {
          obfuscated[key] = request[key];
        }
      }
      return obfuscated;
    }
    return request;
  }
}

/// Details for a request with exception.
///
/// Now extends [ProgressiveRequestContext] for enhanced logging capabilities.
///
/// Usage:
/// ```dart
/// // Preferred: Use factory for easier migration
/// final details = ExceptionRequestContextDetails.fromException(
///   context,
///   await context.jsonOrBody(),
///   exception,
/// );
///
/// // Or use directly with strategies
/// final details = ExceptionRequestContextDetails(
///   dartFrogContext: context,
///   requestIdStrategy: UuidStrategy(),
///   error: exception,
/// );
/// ```
class ExceptionRequestContextDetails extends ProgressiveRequestContext {
  /// Creates exception context details with a backward-compatible factory.
  ///
  /// This factory provides an easier migration path from the old API.
  /// The [requestBody] is added as a custom field if provided.
  factory ExceptionRequestContextDetails.fromException(RequestContext context, dynamic requestBody, Object error) {
    final contextDetails = ExceptionRequestContextDetails._(
      dartFrogContext: context,
      requestIdStrategy: UuidStrategy(),
      error: error,
    );

    // Add request body as custom field if provided
    if (requestBody != null) {
      // ignore: deprecated_member_use_from_same_package
      contextDetails.addField('request_body', RequestContextDetails.obfuscateUserData(requestBody));
    }

    return contextDetails;
  }

  /// Creates exception context details with full strategy configuration.
  ///
  /// This constructor allows full control over context creation with custom strategies.
  ExceptionRequestContextDetails._({
    required super.dartFrogContext,
    required super.requestIdStrategy,
    required Object error,
  }) {
    // Finalize immediately with error information
    finalize(error: error);
  }

  /// Legacy compatibility method for accessing error as JSON.
  @Deprecated('Error information is now in the base class. Use toJson() instead.')
  Map<String, dynamic> get errorToJson => switch (errorObject) {
    final JsonExportable e => e.toJson(),
    final Object e => {'message': e.toString(), 'status_code': statusCode ?? 500},
    null => {'message': 'Unknown error', 'status_code': 500},
  };
}

/// Extension to process the request body
extension ProcessRequestContextBody on RequestContext {
  /// Returns either `Map<String, dynamic>` of request body json or dynamic of body as a future
  Future<dynamic> jsonOrBody() async {
    if (![HttpMethod.post, HttpMethod.put].contains(request.method)) {
      return null;
    }
    try {
      return await request.json();
    } catch (e) {
      try {
        return await request.body();
      } catch (e) {
        return null;
      }
    }
  }
}
