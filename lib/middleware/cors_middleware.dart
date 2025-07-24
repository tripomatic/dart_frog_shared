import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_shared/middleware/cors_config.dart';

/// Creates a CORS middleware with the given configuration
Middleware corsMiddleware({CorsConfig config = const CorsConfig()}) {
  return (Handler handler) {
    return (RequestContext context) async {
      // Handle preflight OPTIONS requests
      if (context.request.method == HttpMethod.options) {
        return Response(
          headers: {
            'Access-Control-Allow-Origin': config.allowedOriginsHeader,
            'Access-Control-Allow-Methods': config.allowedMethodsHeader,
            'Access-Control-Allow-Headers': config.allowedHeadersHeader,
            'Access-Control-Max-Age': config.maxAgeHeader,
          },
        );
      }

      // For non-OPTIONS requests, handle normally and add CORS headers to response
      final response = await handler(context);
      return response.copyWith(
        headers: {
          ...response.headers,
          'Access-Control-Allow-Origin': config.allowedOriginsHeader,
          'Access-Control-Allow-Methods': config.allowedMethodsHeader,
          'Access-Control-Allow-Headers': config.allowedHeadersHeader,
        },
      );
    };
  };
}
