import 'dart:convert';

import '../domain/forecast.dart';
import 'forecast_failure.dart';

const _halfHour = Duration(minutes: 30);

const _indices = {
  'very low': IntensityIndex.veryLow,
  'low': IntensityIndex.low,
  'moderate': IntensityIndex.moderate,
  'high': IntensityIndex.high,
  'very high': IntensityIndex.veryHigh,
};

/// Parses a `/regional/intensity/{from}/fw48h/postcode/{outcode}` body.
/// Throws [NotFoundFailure] for an unknown area and [ParseFailure] for
/// anything else unexpected. Unusable slots are dropped (PRD §8.1).
Forecast parseForecast(String body, {required DateTime fetchedAt}) {
  final Object? json;
  try {
    json = jsonDecode(body);
  } on FormatException {
    throw const ParseFailure();
  }
  if (json case null || {'data': null}) throw const NotFoundFailure();
  if (json case {
    'data': {'shortname': final String region, 'data': final List<Object?> raw},
  }) {
    final slots = [for (final s in raw) ?_slot(s)]
      ..sort((a, b) => a.from.compareTo(b.from));
    return Forecast(region: region, slots: slots, fetchedAt: fetchedAt);
  }
  throw const ParseFailure();
}

ForecastSlot? _slot(Object? json) {
  if (json case {
    'from': final String fromText,
    'to': final String toText,
    'intensity':
        {'forecast': final int forecast} &&
        final Map<String, Object?> intensity,
  }) {
    final from = DateTime.tryParse(fromText);
    final to = DateTime.tryParse(toText);
    // A time without an offset would parse as browser-local, so it's dropped.
    if (from == null || to == null || !from.isUtc || !to.isUtc) return null;
    if (forecast < 0 || to.difference(from) != _halfHour) return null;
    return ForecastSlot(
      from: from,
      to: to,
      intensity: forecast,
      index: _indices[intensity['index']] ?? IntensityIndex.none,
    );
  }
  return null;
}
