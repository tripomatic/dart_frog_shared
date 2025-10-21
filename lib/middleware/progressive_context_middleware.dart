import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_shared/logging/progressive_request_context.dart';
import 'package:dart_frog_shared/logging/strategies/request_id_strategy.dart';
import 'package:dart_frog_shared/logging/strategies/session_tracking_strategy.dart';
import 'package:dart_frog_shared/logging/strategies/user_id_strategy.dart';

/// Middleware that creates and provides [ProgressiveRequestContext] for each request.
///
/// This middleware creates a progressive request context with configured strategies
/// and makes it available to downstream handlers via the Dart Frog provider system.
///
/// The context is automatically enriched with:
/// - Request ID (via [requestIdStrategy])
/// - Session tracking information (via [sessionStrategy], if provided)
/// - User ID (via [userIdStrategy], if provided)
/// - Basic request metadata (method, endpoint, headers, remote address)
///
/// Usage:
/// ```dart
/// // In routes/_middleware.dart
/// Handler middleware(Handler handler) {
///   return handler
///     .use(provider<Logger>((_) => logger))
///     .use(progressiveContextMiddleware(
///       requestIdStrategy: GCloudTraceStrategy(),
///       sessionStrategy: AppCheckSessionStrategy(),
///       userIdStrategy: JwtUserIdStrategy(),
///     ))
///     .use(errorHandlerMiddleware(debug: isDev));
/// }
/// ```
///
/// Route handlers can then access the context:
/// ```dart
/// Future<Response> onRequest(RequestContext context) async {
///   final progressiveContext = context.read<ProgressiveRequestContext>();
///   progressiveContext.addField('cache_hit', true);
///   progressiveContext.logSuccess(logger);
///   return Response.json(body: result);
/// }
/// ```
Middleware progressiveContextMiddleware({
  required RequestIdStrategy requestIdStrategy,
  SessionTrackingStrategy? sessionStrategy,
  UserIdStrategy? userIdStrategy,
  String? appVersion,
}) {
  return (handler) {
    return (context) async {
      // Create progressive context with configured strategies
      final progressiveContext = ProgressiveRequestContext(
        dartFrogContext: context,
        requestIdStrategy: requestIdStrategy,
        sessionStrategy: sessionStrategy,
        userIdStrategy: userIdStrategy,
      );

      // Set app version if provided
      if (appVersion != null) {
        progressiveContext.appVersion = appVersion;
      }

      // Provide to downstream handlers via Dart Frog provider system
      return await handler(context.provide<ProgressiveRequestContext>(() => progressiveContext));
    };
  };
}
