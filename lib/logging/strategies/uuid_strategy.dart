import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_shared/logging/strategies/request_id_strategy.dart';
import 'package:uuid/uuid.dart';

/// Request ID strategy that generates a random UUID v4.
///
/// Use this strategy for non-GCP deployments or when you want to generate
/// unique request IDs without relying on infrastructure-provided headers.
///
/// This strategy does not provide distributed tracing information (trace/span IDs).
class UuidStrategy implements RequestIdStrategy {
  static const Uuid _uuid = Uuid();

  @override
  String generateRequestId(RequestContext context) {
    return _uuid.v4();
  }

  @override
  ({String? traceId, String? spanId})? extractTraceInfo(RequestContext context) {
    // UUID strategy doesn't provide distributed tracing information
    return null;
  }
}
