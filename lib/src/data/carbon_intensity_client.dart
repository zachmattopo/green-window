import 'dart:async';

import 'package:http/http.dart' as http;

import 'forecast_failure.dart';

const _timeout = Duration(seconds: 10);
const _retryDelays = [Duration(seconds: 1), Duration(seconds: 2)];

/// Fetches the raw 48-hour regional forecast. Retries and status mapping
/// follow PRD §10; the body is parsed by `parseForecast`.
class CarbonIntensityClient {
  CarbonIntensityClient(this._http);

  final http.Client _http;

  /// Throws a [ForecastFailure]. [from] is sent as UTC to the minute.
  Future<String> fetch(String outcode, {required DateTime from}) async {
    final start = from.toUtc().toIso8601String().substring(0, 16);
    final uri = Uri.https(
      'api.carbonintensity.org.uk',
      '/regional/intensity/${start}Z/fw48h/postcode/$outcode',
    );
    for (var attempt = 0; ; attempt++) {
      try {
        final response = await _http.get(uri).timeout(_timeout);
        return switch (response.statusCode) {
          200 => response.body,
          400 => throw const InvalidPostcodeFailure(),
          429 => throw const RateLimitedFailure(),
          >= 500 => throw const ServerFailure(),
          _ => throw const ParseFailure(),
        };
      } on TimeoutException {
        throw const TimeoutFailure();
      } on ServerFailure {
        if (attempt == _retryDelays.length) rethrow;
      } on http.ClientException {
        if (attempt == _retryDelays.length) throw const NetworkFailure();
      }
      await Future<void>.delayed(_retryDelays[attempt]);
    }
  }
}
