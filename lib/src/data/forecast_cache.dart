import 'package:shared_preferences/shared_preferences.dart';

import '../domain/appliance.dart';
import '../domain/forecast.dart';
import '../domain/window_finder.dart';
import 'forecast_parser.dart';

/// What the user last chose, restored on the next visit.
typedef LastInputs = ({
  String? outcode,
  Appliance? appliance,
  ClockTime? readyBy,
});

/// Browser storage for the last good forecast per outward code (stored as
/// the raw API body, re-parsed on read) and the last inputs.
class ForecastCache {
  ForecastCache(this._prefs);

  final SharedPreferencesAsync _prefs;

  // Storage can be blocked, full or corrupt. The cache is optional, so every
  // storage error is a miss on read and ignored on write, never a failure.

  Future<Forecast?> forecast(String outcode) async {
    try {
      final body = await _prefs.getString('forecast.$outcode');
      final at = await _prefs.getInt('forecast.$outcode.at');
      if (body == null || at == null) return null;
      return parseForecast(
        body,
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(at, isUtc: true),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveForecast(
    String outcode,
    String body,
    DateTime fetchedAt,
  ) async {
    try {
      await _prefs.setString('forecast.$outcode', body);
      await _prefs.setInt(
        'forecast.$outcode.at',
        fetchedAt.millisecondsSinceEpoch,
      );
    } catch (_) {
      // See above: not saving is fine.
    }
  }

  Future<LastInputs> inputs() async {
    try {
      final appliance = await _prefs.getString('inputs.appliance');
      final readyBy = (await _prefs.getString('inputs.readyBy'))?.split(':');
      final hour = int.tryParse(readyBy?.first ?? '');
      final minute = int.tryParse(readyBy?.last ?? '');
      return (
        outcode: await _prefs.getString('inputs.outcode'),
        appliance: Appliance.values.asNameMap()[appliance],
        readyBy: hour == null || minute == null
            ? null
            : (hour: hour, minute: minute),
      );
    } catch (_) {
      return (outcode: null, appliance: null, readyBy: null);
    }
  }

  Future<void> saveInputs(LastInputs inputs) async {
    final (:outcode, :appliance, :readyBy) = inputs;
    try {
      await _set('inputs.outcode', outcode);
      await _set('inputs.appliance', appliance?.name);
      await _set(
        'inputs.readyBy',
        readyBy == null ? null : '${readyBy.hour}:${readyBy.minute}',
      );
    } catch (_) {
      // See above: not saving is fine.
    }
  }

  Future<void> _set(String key, String? value) =>
      value == null ? _prefs.remove(key) : _prefs.setString(key, value);
}
