import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/forecast_failure.dart';
import '../data/forecast_repository.dart';
import '../domain/appliance.dart';
import '../domain/forecast.dart';
import '../domain/postcode.dart';
import '../domain/window_finder.dart';
import 'green_window_state.dart';

const _maxAge = Duration(minutes: 30);

/// The module's state (PRD §9). Fetches only for a new postcode, Retry, or a
/// forecast over 30 minutes old; everything else recalculates in place.
class GreenWindowCubit extends Cubit<GreenWindowState> {
  GreenWindowCubit(this._repository, {required DateTime Function() now})
    : _now = now,
      super(GreenWindowState(now: now())) {
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) => tick());
  }

  final ForecastRepository _repository;
  final DateTime Function() _now;
  late final Timer _ticker;

  /// Id of the newest load. Older loads drop their results.
  var _latest = 0;
  var _fetching = false;

  /// Brings back the last inputs and their area's forecast.
  Future<void> restore() async {
    final (:outcode, :appliance, :readyBy) = await _repository.inputs();
    if (isClosed) return;
    emit(
      state.copyWith(now: _now(), appliance: appliance, readyBy: () => readyBy),
    );
    if (outcode != null) await _load(outcode, force: false);
  }

  /// Shows a US-4 message without a request, or loads the area.
  Future<void> submitPostcode(String input) async {
    switch (parsePostcode(input)) {
      case ValidOutcode(:final outcode):
        final force = outcode != state.outcode || state.status is! Ready;
        emit(state.copyWith(postcodeProblem: () => null));
        unawaited(_saveInputs(outcode: outcode));
        await _load(outcode, force: force);
      case final problem:
        emit(state.copyWith(postcodeProblem: () => problem));
    }
  }

  void selectAppliance(Appliance appliance) {
    emit(state.copyWith(now: _now(), appliance: appliance));
    unawaited(_saveInputs());
  }

  /// A null [readyBy] clears the deadline.
  void setReadyBy(ClockTime? readyBy) {
    emit(state.copyWith(now: _now(), readyBy: () => readyBy));
    unawaited(_saveInputs());
  }

  Future<void> retry() async {
    final outcode = state.outcode;
    if (outcode != null) await _load(outcode, force: true);
  }

  /// Recalculates so a passed start time is never shown, and refetches an
  /// old forecast. Runs every minute; the UI also calls it on tab resume.
  void tick() {
    if (isClosed) return;
    emit(state.copyWith(now: _now()));
    final forecast = state.forecast;
    if (forecast != null && _isOld(forecast) && !_fetching) {
      unawaited(_load(state.outcode!, force: true));
    }
  }

  Future<void> _load(String outcode, {required bool force}) async {
    final id = ++_latest;
    _fetching = true;
    bool superseded() => id != _latest || isClosed;

    // What's on screen for this area, else the cache; only if still usable.
    var held = state.outcode == outcode ? state.forecast : null;
    held ??= await _repository.cached(outcode);
    if (superseded()) return;
    if (held != null && !_hasWindow(held)) held = null;

    if (held != null && !force && !_isOld(held)) {
      _fetching = false;
      emit(state.copyWith(now: _now(), outcode: outcode, status: Ready(held)));
      return;
    }

    emit(
      state.copyWith(
        now: _now(),
        outcode: outcode,
        status: held == null ? const Loading() : Ready(held, refreshing: true),
      ),
    );

    try {
      final fresh = await _repository.fetch(outcode, now: _now());
      // Same rule as the cache: an empty forecast never hides the last good one.
      if (fresh.slots.isEmpty && held != null) throw const ParseFailure();
      if (superseded()) return;
      emit(state.copyWith(now: _now(), status: Ready(fresh)));
    } on ForecastFailure catch (failure) {
      if (superseded()) return;
      emit(
        state.copyWith(
          now: _now(),
          status: Failed(failure, stale: held),
        ),
      );
    }
    _fetching = false;
  }

  bool _isOld(Forecast forecast) =>
      _now().difference(forecast.fetchedAt) > _maxAge;

  /// PRD §10: a cached forecast counts only with enough future slots.
  bool _hasWindow(Forecast forecast) => findGreenWindow(
    forecast: forecast,
    appliance: state.appliance,
    now: _now(),
  ) is! NoForecast;

  Future<void> _saveInputs({String? outcode}) => _repository.saveInputs((
    outcode: outcode ?? state.outcode,
    appliance: state.appliance,
    readyBy: state.readyBy,
  ));

  @override
  Future<void> close() {
    _ticker.cancel();
    return super.close();
  }
}
