import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/forecast_failure.dart';
import '../../domain/forecast.dart';
import '../../domain/london_time.dart';
import '../../domain/window_finder.dart';
import '../green_window_cubit.dart';
import '../green_window_state.dart';

/// The result area for each PRD §9 status, with copy from §8.5 and §10.
class ResultView extends StatelessWidget {
  const ResultView(this.state, {super.key});

  final GreenWindowState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<GreenWindowCubit>();
    final retry = OutlinedButton(
      onPressed: cubit.retry,
      child: const Text('Retry'),
    );
    return switch (state.status) {
      Idle() => const Text(
        'Enter your postcode and pick an appliance. Green Window finds the '
        'time in the next 48 hours when your region’s electricity is '
        'cleanest.',
      ),
      Loading() => const Center(
        child: CircularProgressIndicator(
          semanticsLabel: 'Loading the forecast',
        ),
      ),
      Failed(:final failure, stale: null) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_failureMessage(failure)),
          const SizedBox(height: 8),
          retry,
        ],
      ),
      _ => _result(context, cubit, retry),
    };
  }

  /// Ready, or Failed with a stale forecast: there's an outcome to show.
  Widget _result(BuildContext context, GreenWindowCubit cubit, Widget retry) {
    final forecast = state.forecast!;
    final outcome = state.outcome!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // One sentence for screen readers (PRD §11), with the weekday. Not a
        // live region: the module announces changes, but not the minute tick.
        Semantics(
          excludeSemantics: true,
          label: resultSentence(state),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _headline(outcome),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              for (final line in _lines(state)) Text(line),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            if (outcome case NotEnoughTime(:final deadline))
              OutlinedButton(
                onPressed: cubit.planForTomorrow,
                child: Text('Plan for ${clockLabel(deadline)} tomorrow'),
              ),
            if (outcome is NoForecast || state.status is Failed) retry,
          ],
        ),
        const SizedBox(height: 24),
        _SlotList(forecast: forecast, outcome: outcome, now: state.now),
      ],
    );
  }
}

/// What a screen reader hears for the result area (PRD §11); null when
/// there's no result or error to read.
String? resultSentence(GreenWindowState state) => switch (state.status) {
  Idle() || Loading() => null,
  Failed(:final failure, stale: null) => _failureMessage(failure),
  _ => [_headline(state.outcome!, spoken: true), ..._lines(state)].join(' '),
};

/// The lines under the headline, for a state with a forecast.
List<String> _lines(GreenWindowState state) {
  final updated = clockLabel(state.forecast!.fetchedAt);
  return [
    if (state.outcome
        case Wait(:final forecastEnd?) || StartNow(:final forecastEnd?))
      'Forecast only runs until ${clockLabel(forecastEnd)}.',
    state.forecast!.region,
    'Forecast updated $updated.',
    if (state.status case Ready(refreshing: true)) 'Updating…',
    if (state.status is Failed)
      "Couldn't update. Showing the forecast from $updated.",
  ];
}

/// PRD §8.5 headline. [spoken] adds the weekday after "tonight" and the like.
String _headline(
  WindowOutcome outcome, {
  bool spoken = false,
}) => switch (outcome) {
  NoForecast() => "There isn't enough forecast data to plan this right now.",
  NotEnoughTime(:final deadline, :final earliestFinish) =>
    "There isn't time to finish before ${clockLabel(deadline)}. "
        'The earliest finish is ${clockLabel(earliestFinish)}.',
  Wait(:final best, :final day, :final percentCleaner) => [
    'Start at ${clockLabel(best.start)} $day'
        '${spoken && day != weekdayName(best.start) ? ' (${weekdayName(best.start)})' : ''}.',
    'Ready by ${clockLabel(best.finish)}.',
    if (percentCleaner != null) '$percentCleaner% cleaner than starting now.',
  ].join(' '),
  StartNow() => "Start now. Waiting won't make it meaningfully cleaner.",
};

String _failureMessage(ForecastFailure failure) => switch (failure) {
  NetworkFailure() ||
  TimeoutFailure() ||
  ServerFailure() => "Couldn't reach the forecast service.",
  NotFoundFailure() => "We couldn't find that postcode area.",
  InvalidPostcodeFailure() => "That doesn't look like a UK postcode.",
  RateLimitedFailure() =>
    'The forecast service is busy. Try again in a minute.',
  ParseFailure() => "The forecast service sent something we couldn't read.",
};

/// shortcut: plain text stands in for the Phase 6 chart.
class _SlotList extends StatelessWidget {
  const _SlotList({
    required this.forecast,
    required this.outcome,
    required this.now,
  });

  final Forecast forecast;
  final WindowOutcome outcome;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final window = switch (outcome) {
      Wait(:final best) => best,
      StartNow(now: final run) => run,
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Next 48 hours (gCO2/kWh)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        for (final slot in forecast.slots)
          if (slot.to.isAfter(now))
            Text(
              '${weekdayName(slot.from).substring(0, 3)} '
              '${clockLabel(slot.from)}  ${slot.intensity}  '
              '${_band(slot.index)}'
              '${window != null && slot.to.isAfter(window.start) && slot.from.isBefore(window.finish) ? '  ← your window' : ''}',
            ),
      ],
    );
  }
}

String _band(IntensityIndex index) => switch (index) {
  IntensityIndex.none => '',
  IntensityIndex.veryLow => 'very low',
  IntensityIndex.low => 'low',
  IntensityIndex.moderate => 'moderate',
  IntensityIndex.high => 'high',
  IntensityIndex.veryHigh => 'very high',
};
