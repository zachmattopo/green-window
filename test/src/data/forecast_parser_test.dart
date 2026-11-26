import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:green_window/src/data/forecast_failure.dart';
import 'package:green_window/src/data/forecast_parser.dart';
import 'package:green_window/src/domain/forecast.dart';

final fetchedAt = DateTime.utc(2026, 11, 26, 11);

Forecast parse(String body) => parseForecast(body, fetchedAt: fetchedAt);

Map<String, Object?> slot(
  String from,
  String to,
  Object? forecast, [
  Object? index = 'low',
]) => {
  'from': from,
  'to': to,
  'intensity': {'forecast': forecast, 'index': index},
};

String body(List<Object?> slots) => jsonEncode({
  'data': {'shortname': 'South England', 'data': slots},
});

void main() {
  test('a garbled payload is a ParseFailure', () {
    for (final garbled in [
      '{"data": {"shortname": "South',
      '<html>502 Bad Gateway</html>',
      '[]',
      '{"data": []}',
      '{"data": {"shortname": 12, "data": []}}',
      '{"data": {"shortname": "South England", "data": {}}}',
    ]) {
      expect(
        () => parse(garbled),
        throwsA(isA<ParseFailure>()),
        reason: garbled,
      );
    }
  });

  test('a null body or null data is NotFound', () {
    expect(() => parse('null'), throwsA(isA<NotFoundFailure>()));
    expect(() => parse('{"data": null}'), throwsA(isA<NotFoundFailure>()));
  });

  test('bad slots are dropped, good ones kept, unknown index has no band', () {
    final forecast = parse(
      body([
        slot('2026-11-26T11:30Z', '2026-11-26T12:00Z', 180, 'high'),
        slot('2026-11-26T11:00Z', '2026-11-26T11:30Z', 252, 'very high'),
        slot('2026-11-26T12:00Z', '2026-11-26T12:30Z', -1), // negative
        slot('2026-11-26T12:30Z', '2026-11-26T13:00Z', 99.5), // not whole
        slot('2026-11-26T13:00Z', '2026-11-26T13:30Z', null), // missing
        slot('2026-11-26T13:30Z', '2026-11-26T14:30Z', 100), // 1 h long
        slot('2026-11-26T14:00', '2026-11-26T14:30', 100), // no offset
        slot('yesterday', '2026-11-26T15:00Z', 100), // bad date
        'not a slot',
        slot('2026-11-26T15:00Z', '2026-11-26T15:30Z', 40, 'extreme'),
        slot('2026-11-26T15:30Z', '2026-11-26T16:00Z', 30, null),
      ]),
    );
    expect(forecast.region, 'South England');
    expect(forecast.fetchedAt, fetchedAt);
    expect(
      [for (final s in forecast.slots) (s.from.hour, s.intensity, s.index)],
      [
        (11, 252, IntensityIndex.veryHigh), // sorted into time order
        (11, 180, IntensityIndex.high),
        (15, 40, IntensityIndex.none),
        (15, 30, IntensityIndex.none),
      ],
    );
    expect(forecast.slots.first.from, DateTime.utc(2026, 11, 26, 11));
  });

  test('the saved live response parses in full', () {
    final fixture = File('assets/fixtures/forecast_rg10.json')
        .readAsStringSync();
    final forecast = parse(fixture);
    expect(forecast.region, 'South England');
    expect(forecast.slots, hasLength(96));
    expect(forecast.slots.first.index.isDirty, isTrue);
  });
}
