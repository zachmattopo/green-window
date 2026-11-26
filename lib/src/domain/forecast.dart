/// One usable half-hour slot. Times are UTC; [intensity] is gCO2/kWh.
class ForecastSlot {
  const ForecastSlot({
    required this.from,
    required this.to,
    required this.intensity,
  });

  final DateTime from;
  final DateTime to;
  final int intensity;
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
