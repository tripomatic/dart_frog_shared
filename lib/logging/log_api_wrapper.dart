/// Abstract base class for log API wrappers
///
/// Implementations of this class provide different methods for sending logs
/// to external logging services (e.g., Papertrail, SolarWinds Observability).
abstract class LogApiWrapper {
  /// Tracks a json event with the logging service
  ///
  /// The [body] parameter should be a JSON-encoded string representing
  /// the log event to be sent to the logging service.
  Future<void> trackEvent(String body);
}
