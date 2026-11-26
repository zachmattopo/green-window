import '../domain/forecast.dart';
import 'carbon_intensity_client.dart';
import 'forecast_cache.dart';
import 'forecast_parser.dart';

/// The client plus the cache: a successful fetch replaces the cached copy.
/// Also passes the last inputs through, so the Cubit only needs this.
class ForecastRepository {
  ForecastRepository(this._client, this._cache);

  final CarbonIntensityClient _client;
  final ForecastCache _cache;

  /// The last good forecast for [outcode], however old. The caller decides
  /// whether it still has enough future slots (PRD §10).
  Future<Forecast?> cached(String outcode) => _cache.forecast(outcode);

  /// Throws a `ForecastFailure`. Only a body that parses is cached.
  Future<Forecast> fetch(String outcode, {required DateTime now}) async {
    final body = await _client.fetch(outcode, from: now);
    final forecast = parseForecast(body, fetchedAt: now);
    // An empty forecast must not replace the last good one.
    if (forecast.slots.isNotEmpty) {
      await _cache.saveForecast(outcode, body, now);
    }
    return forecast;
  }

  Future<LastInputs> inputs() => _cache.inputs();

  Future<void> saveInputs(LastInputs inputs) => _cache.saveInputs(inputs);
}
