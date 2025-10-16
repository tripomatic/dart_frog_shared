import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_shared/exceptions/exceptions.dart';
import 'package:logging/logging.dart';

/// Middleware that automatically catches and converts exceptions to JSON responses.
///
/// This middleware provides centralized error handling for all routes by:
/// - Catching [ApiException] and converting them to proper HTTP responses
/// - Catching unexpected exceptions and wrapping them in [InternalServerErrorException]
/// - Logging all errors with appropriate severity levels
/// - Supporting debug mode to include internal error details
///
/// Usage in routes/_middleware.dart:
/// ```dart
/// Handler middleware(Handler handler) {
///   final logger = Logger('MyApi');
///
///   return handler
///     .use(provider<Logger>((_) => logger))
///     .use(errorHandlerMiddleware(debug: env['DEBUG_MODE'] == 'true'));
/// }
/// ```
///
/// Route handlers can now simply throw exceptions without manual try-catch:
/// ```dart
/// Future<Response> onRequest(RequestContext context) async {
///   if (invalidInput) {
///     throw BadRequestException(message: 'Invalid input');
///   }
///   return Response.json(body: result);
/// }
/// ```
///
/// Custom error handling is still possible by catching specific exceptions
/// before they reach the middleware:
/// ```dart
/// Future<Response> onRequest(RequestContext context) async {
///   try {
///     return await specialOperation();
///   } on SpecificException catch (e) {
///     return Response.json(body: {'custom': 'response'});
///   }
///   // All other exceptions caught by middleware
/// }
/// ```
Middleware errorHandlerMiddleware({bool debug = false}) {
  return (handler) {
    return (context) async {
      try {
        // Execute the route handler
        return await handler(context);
      } on ApiException catch (e, stackTrace) {
        // ApiException - log with appropriate severity based on status code
        // 4xx (client errors) → WARNING, 5xx (server errors) → SEVERE
        final logger = context.read<Logger>();
        if (e.statusCode >= 500) {
          logger.severe('API error: ${e.message}', e, stackTrace);
        } else {
          logger.warning('API error: ${e.message}', e, stackTrace);
        }
        return e.toResponse(debug: debug);
      } catch (e, stackTrace) {
        // Unexpected error - wrap in InternalServerErrorException
        // Log as severe since these indicate bugs or unexpected conditions
        final logger = context.read<Logger>();
        logger.severe('Unexpected error: $e', e, stackTrace);
        return InternalServerErrorException(
          message: 'Unexpected error: $e',
          responseBodyMessage: 'Internal server error',
        ).toResponse(debug: debug);
      }
    };
  };
}
