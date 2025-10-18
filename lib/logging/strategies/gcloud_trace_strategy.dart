import 'package:dart_frog/dart_frog.dart';
import 'package:dart_frog_shared/logging/strategies/request_id_strategy.dart';
import 'package:dart_frog_shared/logging/strategies/uuid_strategy.dart';
import 'package:logging/logging.dart';

/// Request ID strategy that extracts trace information from Google Cloud Run.
///
/// Extracts the trace ID from the `X-Cloud-Trace-Context` header, which is
/// automatically set by Google Cloud Run for all requests.
///
/// Header format: `TRACE_ID/SPAN_ID;o=TRACE_TRUE`
/// - TRACE_ID: 32-character hex value (128-bit)
/// - SPAN_ID: 64-bit decimal value
///
/// Example: `105445aa7843bc8bf206b12000100000/1;o=1`
///
/// **Fallback Behavior**: If the X-Cloud-Trace-Context header is missing
/// (e.g., misconfiguration or non-GCP environment), this strategy will
/// automatically fall back to generating a UUID and log a warning.
class GCloudTraceStrategy implements RequestIdStrategy {
  /// Header name for Google Cloud trace context
  static const String _traceContextHeader = 'x-cloud-trace-context';

  static final Logger _logger = Logger('GCloudTraceStrategy');
  static final UuidStrategy _fallbackStrategy = UuidStrategy();

  @override
  String generateRequestId(RequestContext context) {
    final traceContext = context.request.headers[_traceContextHeader];

    if (traceContext == null || traceContext.isEmpty) {
      _logger.warning(
        'X-Cloud-Trace-Context header not found. '
        'Falling back to UUID generation. '
        'Ensure this application is deployed on Google Cloud Run, '
        'or switch to UuidStrategy for non-GCP environments.',
      );
      return _fallbackStrategy.generateRequestId(context);
    }

    // Extract TRACE_ID (before the first '/')
    final traceId = traceContext.split('/').first;
    return traceId;
  }

  @override
  ({String? traceId, String? spanId})? extractTraceInfo(RequestContext context) {
    final traceContext = context.request.headers[_traceContextHeader];

    if (traceContext == null || traceContext.isEmpty) {
      return null;
    }

    // Parse: TRACE_ID/SPAN_ID;o=TRACE_TRUE
    final parts = traceContext.split('/');
    if (parts.isEmpty) {
      return null;
    }

    final traceId = parts[0];
    String? spanId;

    if (parts.length > 1) {
      // Extract SPAN_ID (before the ';')
      final spanPart = parts[1].split(';').first;
      spanId = spanPart;
    }

    return (traceId: traceId, spanId: spanId);
  }
}
