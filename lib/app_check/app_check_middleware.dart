import 'dart:async';
import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:logging/logging.dart';

import 'package:dart_frog_shared/logging/request_context_details.dart';
import 'package:dart_frog_shared/app_check/app_check_config.dart';
import 'package:dart_frog_shared/app_check/app_check_token_cache.dart';
import 'package:dart_frog_shared/app_check/firebase_app_check_service.dart';

/// Creates App Check middleware for Dart Frog applications
Middleware appCheckMiddleware({required AppCheckConfig config}) {
  final logger = Logger('AppCheckMiddleware');
  final tokenCache = AppCheckTokenCache(maxSize: config.cacheMaxSize, tokenDuration: config.cacheDuration);
  final firebaseService = FirebaseAppCheckService(config);

  return (handler) {
    return (context) async {
      // Skip App Check for exempt paths
      final path = context.request.uri.path;
      if (config.exemptPaths.contains(path)) {
        logger.fine('Skipping App Check for exempt path: $path');
        return handler(context);
      }

      // Skip App Check in dev mode
      if (config.enableDevMode) {
        logger.info('App Check bypassed in dev mode');
        return handler(context);
      }

      // Get App Check token from header
      final appCheckToken = context.request.headers['X-Firebase-AppCheck'];

      if (appCheckToken == null || appCheckToken.isEmpty) {
        logger.warning('Missing App Check token');
        return _unauthorizedResponse(context, 'Missing App Check token', config.enableDevMode);
      }

      // Check cache first
      if (tokenCache.contains(appCheckToken)) {
        logger.fine('App Check token found in cache');
        return handler(context);
      }

      // Verify token with Firebase
      try {
        final isValid = await firebaseService.verifyToken(appCheckToken);

        if (!isValid) {
          logger.warning('Invalid App Check token');
          return _unauthorizedResponse(context, 'Invalid App Check token', config.enableDevMode);
        }

        // Cache the valid token
        tokenCache.add(appCheckToken);
        logger.fine('App Check token verified and cached');

        return handler(context);
      } catch (e, stack) {
        logger.severe('App Check verification error', e, stack);

        // Log the error with context
        try {
          final body = await _getRequestBody(context);
          final details = ExceptionRequestContextDetails(context, body, e);
          logger.severe('App Check verification failed with context', details);
        } catch (_) {
          // If logging with context fails, just log the error
          logger.severe('App Check verification failed', e, stack);
        }

        return _errorResponse(context, 'App Check verification failed', config.enableDevMode);
      }
    };
  };
}

/// Creates an unauthorized response
Response _unauthorizedResponse(RequestContext context, String message, bool includeDetails) {
  final responseBody = {'error': includeDetails ? message : 'Unauthorized'};

  return Response.json(body: responseBody, statusCode: HttpStatus.unauthorized);
}

/// Creates an error response
Response _errorResponse(RequestContext context, String message, bool includeDetails) {
  final responseBody = {'error': includeDetails ? message : 'Internal server error'};

  return Response.json(body: responseBody, statusCode: HttpStatus.internalServerError);
}

/// Gets the request body safely
Future<Object?> _getRequestBody(RequestContext context) async {
  try {
    final contentType = context.request.headers['content-type'];
    if (contentType?.contains('application/json') ?? false) {
      return await context.request.json();
    }
    return await context.request.body();
  } catch (_) {
    return null;
  }
}
