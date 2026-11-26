/// NESO's band for a slot's intensity (PRD §8.1). Only colours the chart.
enum IntensityIndex {
  none,
  veryLow,
  low,
  moderate,
  high,
  veryHigh;

  bool get isDirty => this == high || this == veryHigh;
}

/// One usable half-hour slot. Times are UTC; [intensity] is gCO2/kWh.
class ForecastSlot {
  const ForecastSlot({
    required this.from,
    required this.to,
    required this.intensity,
    this.index = IntensityIndex.none,
  });

  final DateTime from;
  final DateTime to;
  final int intensity;
  final IntensityIndex index;
}

/// A regional forecast: usable slots in time order, possibly with gaps.
class Forecast {
  const Forecast({
    required this.region,
    required this.slots,
    required this.fetchedAt,
  });

  final String region;
  final List<ForecastSlot> slots;
  final DateTime fetchedAt;
}
