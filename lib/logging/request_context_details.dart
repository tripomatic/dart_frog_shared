import 'dart:io';
import 'dart:math';

import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_shared/exceptions/json_exportable.dart';

/// Base class for request details
///
/// See implementation: [ExceptionRequestContextDetails] and [ResponseRequestContextDetails]
abstract class RequestContextDetails {
  /// Request context
  final RequestContext context;

  /// Request body
  final dynamic requestBody;

  RequestContextDetails(this.context, this.requestBody);

  /// Request endpoint
  Uri get endpoint => context.request.uri;

  /// Request headers
  Map<String, String> get requestHeaders => context.request.headers;

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
    'request_headers': obfuscateUserData(requestHeaders),
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

/// Details for a request with exception
///
/// Usage:
/// ```dart
/// final result = ExceptionRequestContextDetails(context, await context.jsonOrBody(), exception);
/// ```
class ExceptionRequestContextDetails extends RequestContextDetails {
  final Object error;

  ExceptionRequestContextDetails(super.context, super.body, this.error);

  Map<String, dynamic> get errorToJson => switch (error) {
    final JsonExportable e => e.toJson(),
    // final ApiException e => {
    //     'message': e.message,
    //     'response_message': e.responseMessage,
    //     'status_code': e.statusCode,
    //   },
    final Object e => {'message': e.toString(), 'status_code': 500},
  };

  @override
  Map<String, dynamic> toJson() => {...errorToJson, ...super.toJson()};

  @override
  String toString() => '[${errorToJson['status_code']}] ${super.toString()}: ${errorToJson['message']}';
}

/// Details for a request with response
///
/// Usage:
/// ```dart
/// final result = ResponseRequestContextDetails(context, await context.jsonOrBody(), response);
/// ```
class ResponseRequestContextDetails extends RequestContextDetails {
  final Response response;

  ResponseRequestContextDetails(super.context, super.body, this.response);

  Map<String, dynamic> get responseToJson => {'status_code': response.statusCode};

  @override
  Map<String, dynamic> toJson() => {...responseToJson, ...super.toJson()};

  @override
  String toString() => '[${response.statusCode}] ${super.toString()}';
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
