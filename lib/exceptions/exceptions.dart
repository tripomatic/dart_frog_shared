import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_shared/exceptions/json_exportable.dart';

/// Base class for all exceptions thrown by the SSO server.
///
/// These exceptions can be directly converted to a [Response] object using [toResponse].
abstract class ApiException implements Exception, JsonExportable {
  /// Internal message (not to be included in the response)
  final String message;

  /// Response message (to be included in the response)
  final String responseMessage;

  /// HTTP status code
  final int statusCode;

  ApiException({required this.message, required this.statusCode, required this.responseMessage})
    : assert(statusCode >= 400 && statusCode < 600);

  @override
  Map<String, dynamic> toJson() {
    return {'status_code': statusCode, 'error': responseMessage, 'debug_message': message};
  }

  /// Converts the exception to a [Response] object.
  ///
  /// If [debug] is `true`, the response will include the internal message.
  Response toResponse({bool debug = false}) {
    return Response.json(
      statusCode: statusCode,
      body: {'status': statusCode, 'error': responseMessage, if (debug) 'debug_message': message},
    );
  }

  @override
  String toString() {
    return '$message [$statusCode] $responseMessage';
  }
}

/// An exception thrown when the request is invalid.
class BadRequestException extends ApiException {
  BadRequestException({required super.message, String? responseBodyMessage})
    : super(statusCode: HttpStatus.badRequest, responseMessage: responseBodyMessage ?? 'Invalid Request');
}

/// An exception thrown when the request method is not allowed.
class MethodNotAllowedException extends ApiException {
  MethodNotAllowedException({required super.message, String? responseBodyMessage})
    : super(statusCode: HttpStatus.methodNotAllowed, responseMessage: responseBodyMessage ?? 'Method Not Allowed');
}

/// An exception thrown when the user is not authorized to perform the action.
class UnauthorizedException extends ApiException {
  UnauthorizedException({required super.message, String? responseBodyMessage})
    : super(statusCode: HttpStatus.unauthorized, responseMessage: responseBodyMessage ?? 'Unauthorized');
}

/// Exception thrown specifically for anonymous users.
class AnonymousUnauthorizedException extends UnauthorizedException {
  AnonymousUnauthorizedException({required super.message, super.responseBodyMessage});
}

/// An exception thrown when the user lacks permission to perform the action.
///
/// Use this for authenticated users who don't have the required role/permission.
/// For missing or invalid credentials, use [UnauthorizedException] instead.
class ForbiddenException extends ApiException {
  ForbiddenException({required super.message, String? responseBodyMessage})
    : super(statusCode: HttpStatus.forbidden, responseMessage: responseBodyMessage ?? 'Forbidden');
}

/// An exception thrown if internal logic fails.
class InternalServerErrorException extends ApiException {
  InternalServerErrorException({required super.message, String? responseBodyMessage})
    : super(
        statusCode: HttpStatus.internalServerError,
        responseMessage: responseBodyMessage ?? 'Internal Server Error',
      );
}

/// An exception thrown when the data is somehow incorrect
class DataException extends ApiException {
  DataException({required super.message, String? responseBodyMessage})
    : super(
        statusCode: HttpStatus.internalServerError,
        responseMessage: responseBodyMessage ?? 'Internal Server Error',
      );
}

/// An exception thrown when the requested resource is not found.
class NotFoundException extends ApiException {
  NotFoundException({required super.message, String? responseBodyMessage})
    : super(statusCode: HttpStatus.notFound, responseMessage: responseBodyMessage ?? 'Not Found');
}

/// An exception thrown when there is a conflict with the current state.
class ConflictException extends ApiException {
  ConflictException({required super.message, String? responseBodyMessage})
    : super(statusCode: HttpStatus.conflict, responseMessage: responseBodyMessage ?? 'Conflict');
}
