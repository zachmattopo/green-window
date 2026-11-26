/// Why a forecast couldn't be loaded (PRD §10). Thrown by the data layer.
sealed class ForecastFailure implements Exception {
  const ForecastFailure();
}

/// No connection, after retries.
final class NetworkFailure extends ForecastFailure {
  const NetworkFailure();
}

/// No response within 10 s. Never retried.
final class TimeoutFailure extends ForecastFailure {
  const TimeoutFailure();
}

/// 5xx, after retries.
final class ServerFailure extends ForecastFailure {
  const ServerFailure();
}

/// The API doesn't know this outward code (200 with a `null` body).
final class NotFoundFailure extends ForecastFailure {
  const NotFoundFailure();
}

/// 400: the API rejected the outward code's format.
final class InvalidPostcodeFailure extends ForecastFailure {
  const InvalidPostcodeFailure();
}

/// 429.
final class RateLimitedFailure extends ForecastFailure {
  const RateLimitedFailure();
}

/// Malformed JSON, an unexpected shape, or an unexpected status.
final class ParseFailure extends ForecastFailure {
  const ParseFailure();
}
