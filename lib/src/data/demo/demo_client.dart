import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// When `assets/fixtures/forecast_rg10.json` was captured. `?demo=fixture`
/// freezes the clock here, so its answer is the same on every visit.
final fixtureCapturedAt = DateTime.utc(2026, 11, 26, 11);

/// PRD §12: replaces the network so each failure can be shown on demand.
/// Null for no mode or an unknown one, which runs live.
http.Client? demoClient(String? mode, http.Client live) {
  var first = true;
  return switch (mode) {
    // Any postcode gets the RG10 forecast; the banner says it isn't live.
    'fixture' => MockClient(
      (_) async => http.Response(
        await rootBundle.loadString('assets/fixtures/forecast_rg10.json'),
        200,
      ),
    ),
    // Only the first request waits past the 10 s timeout, so a second
    // search made straight after it finishes first.
    'slow' => MockClient((request) async {
      if (first) {
        first = false;
        await Future<void>.delayed(const Duration(seconds: 12));
      }
      return live.get(request.url);
    }),
    'busy' => MockClient((_) async => http.Response('', 429)),
    'error' => MockClient((_) async => http.Response('', 500)),
    'garbled' => MockClient((_) async => http.Response('{"data": [', 200)),
    'offline' => MockClient((_) => throw http.ClientException('demo offline')),
    _ => null,
  };
}
