import 'package:dart_frog/dart_frog.dart';

/// Strategy for generating or extracting request IDs.
///
/// Implementations determine how request IDs are created and whether
/// distributed tracing information (trace/span IDs) is available.
abstract class RequestIdStrategy {
  /// Generates or extracts a unique request ID from the request context.
  ///
  /// This ID should be unique per request and suitable for correlation
  /// across logs and distributed systems.
  String generateRequestId(RequestContext context);

  /// Optional: Extract distributed tracing information.
  ///
  /// Returns trace and span IDs for distributed tracing systems.
  /// Returns `null` if tracing information is not available.
  ({String? traceId, String? spanId})? extractTraceInfo(RequestContext context) => null;
}
