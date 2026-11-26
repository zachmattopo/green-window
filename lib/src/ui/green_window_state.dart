import '../data/forecast_failure.dart';
import '../domain/appliance.dart';
import '../domain/forecast.dart';
import '../domain/postcode.dart';
import '../domain/window_finder.dart';

/// Where the forecast for the current outward code stands (PRD §9).
sealed class GreenWindowStatus {
  const GreenWindowStatus();
}

/// No postcode yet.
final class Idle extends GreenWindowStatus {
  const Idle();
}

/// Fetching, with no usable cached forecast to show meanwhile.
final class Loading extends GreenWindowStatus {
  const Loading();
}

/// A forecast to show. [refreshing] marks a cached one being updated.
final class Ready extends GreenWindowStatus {
  const Ready(this.forecast, {this.refreshing = false});
  final Forecast forecast;
  final bool refreshing;
}

/// The fetch failed. [stale] is the last good forecast, if still usable.
/// [retrying] marks a retry in flight, so the failure stays on screen.
final class Failed extends GreenWindowStatus {
  const Failed(this.failure, {this.stale, this.retrying = false});
  final ForecastFailure failure;
  final Forecast? stale;
  final bool retrying;
}

class GreenWindowState {
  GreenWindowState({
    required this.now,
    this.outcode,
    this.appliance = Appliance.washingMachine,
    this.readyBy,
    this.skippedDeadline,
    this.postcodeProblem,
    this.status = const Idle(),
  });

  /// When [outcome] was worked out. The Cubit moves it on every minute.
  final DateTime now;
  final String? outcode;
  final Appliance appliance;
  final ClockTime? readyBy;

  /// Set by "Plan for {deadline} tomorrow"; see `findGreenWindow`.
  final DateTime? skippedDeadline;

  /// An [InvalidPostcode] or [NotCovered] to show by the field (US-4).
  final PostcodeResult? postcodeProblem;
  final GreenWindowStatus status;

  /// The forecast on screen: fresh, being refreshed, or stale after a failure.
  Forecast? get forecast => switch (status) {
    Ready(:final forecast) || Failed(stale: final forecast?) => forecast,
    _ => null,
  };

  /// Derived from the inputs, so changing one never needs a fetch.
  late final WindowOutcome? outcome = switch (forecast) {
    final forecast? => findGreenWindow(
      forecast: forecast,
      appliance: appliance,
      readyBy: readyBy,
      skippedDeadline: skippedDeadline,
      now: now,
    ),
    null => null,
  };

  /// Nullable fields take a function, so they can be cleared with `() => null`.
  GreenWindowState copyWith({
    DateTime? now,
    String? outcode,
    Appliance? appliance,
    ClockTime? Function()? readyBy,
    DateTime? Function()? skippedDeadline,
    PostcodeResult? Function()? postcodeProblem,
    GreenWindowStatus? status,
  }) => GreenWindowState(
    now: now ?? this.now,
    outcode: outcode ?? this.outcode,
    appliance: appliance ?? this.appliance,
    readyBy: readyBy == null ? this.readyBy : readyBy(),
    skippedDeadline: skippedDeadline == null
        ? this.skippedDeadline
        : skippedDeadline(),
    postcodeProblem: postcodeProblem == null
        ? this.postcodeProblem
        : postcodeProblem(),
    status: status ?? this.status,
  );
}
