import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:morphnext/morphnext.dart';
import 'package:reel_text/reel_text.dart';

import '../../data/forecast_failure.dart';
import '../../domain/london_time.dart';
import '../../domain/window_finder.dart';
import '../green_window_cubit.dart';
import '../green_window_state.dart';
import '../theme.dart';
import 'slide_in.dart';

const _blank = '--:--';

/// The answer on the first screen for each PRD §9 status: the region label,
/// the start time and day word, the §8.5 headline, and its action.
class ResultView extends StatelessWidget {
  const ResultView(this.state, {super.key});

  final GreenWindowState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<GreenWindowCubit>();
    final compact = isCompact(context);
    final k = compact
        ? 1.0
        : (MediaQuery.sizeOf(context).width / 1440).clamp(0.6, 1.0);
    final outcome = state.outcome;
    final region = state.forecast?.region.toUpperCase();

    final timeStyle = TextStyle(
      fontSize: compact ? 140 : 315 * k,
      fontWeight: FontWeight.w700,
      height: 0.82,
      color: slate,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final dayStyle = TextStyle(
      fontSize: compact ? 48 : 99 * k,
      fontWeight: FontWeight.w500,
      height: 0.9,
    );
    final (icon, big, day) = switch ((state.status, outcome)) {
      (Idle(), _) => (Icons.eco, _blank, ''),
      (Loading(), _) => (Icons.hourglass_empty, _blank, 'Loading'),
      (_, Wait(:final best, :final day)) => (
        Icons.schedule,
        clockLabel(best.start),
        day,
      ),
      (_, StartNow()) => (Icons.play_arrow, 'Now', ''),
      (_, NotEnoughTime(:final earliestFinish)) => (
        Icons.timer_off,
        clockLabel(earliestFinish),
        'earliest finish',
      ),
      _ => (Icons.cloud_off, _blank, ''),
    };
    final label = switch (outcome) {
      NotEnoughTime(:final deadline) =>
        '$region · READY BY ${clockLabel(deadline)}',
      _ when region != null => '$region · CLEANEST TIME TO START',
      _ => 'CLEANEST TIME TO START',
    };
    final headline = switch (state.status) {
      Idle() => [
        const TextSpan(
          text:
              'Enter your postcode and pick an appliance. Green Window finds '
              'the time in the next 48 hours when your region’s electricity '
              'is cleanest.',
        ),
      ],
      Loading() => [
        TextSpan(text: 'Getting the forecast for ${state.outcode}…'),
      ],
      Failed(:final failure, stale: null) => [
        TextSpan(text: _failureMessage(failure)),
      ],
      _ => switch (outcome!) {
        Wait(:final best, :final percentCleaner?) => [
          TextSpan(text: 'Ready by ${clockLabel(best.finish)} · '),
          TextSpan(
            text: '$percentCleaner% cleaner',
            style: const TextStyle(color: purple),
          ),
          const TextSpan(text: ' than starting now'),
        ],
        Wait(:final best) => [
          TextSpan(text: 'Ready by ${clockLabel(best.finish)}.'),
        ],
        final other => [TextSpan(text: _headline(other))],
      },
    };
    final forecastEnd = switch (outcome) {
      Wait(:final forecastEnd?) || StartNow(:final forecastEnd?) => forecastEnd,
      _ => null,
    };

    final retrying = switch (state.status) {
      Failed(:final retrying) => retrying,
      _ => false,
    };
    final retry = FilledButton(
      onPressed: cubit.retry,
      child: const Text('Retry'),
    );
    final action = switch (outcome) {
      NotEnoughTime(:final deadline) => FilledButton(
        onPressed: cubit.planForTomorrow,
        child: Text('Plan for ${clockLabel(deadline)} tomorrow'),
      ),
      // A failed refresh already offers Retry in its notice.
      NoForecast() when state.status is! Failed => retry,
      null when state.status is Failed => retry,
      _ => null,
    };

    // The time and the day word sit in the same place in every state: the
    // time is at least as wide as "00:00", and the day word's line is there
    // even when it's empty.
    final time = Stack(
      children: [
        Visibility(
          visible: false,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: Text('00:00', style: timeStyle),
        ),
        _BigTime(big, waiting: state.status is Loading, style: timeStyle),
      ],
    );
    final dayWord = SizedBox(
      height: dayStyle.fontSize! * dayStyle.height!,
      // Shrinks a long day word on a narrow window rather than wrapping it.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.bottomLeft,
        child: ReelText(day, style: dayStyle),
      ),
    );

    final answer = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // One sentence for screen readers (PRD §11), with the weekday. Not a
        // live region: the module announces changes, but not the minute tick.
        Semantics(
          excludeSemantics: true,
          label:
              resultSentence(state) ??
              headline.map((span) => span.text ?? '').join(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AnimatedMorphIcon(icon: icon, size: 28 * k, color: slate),
                  SizedBox(width: 12 * k),
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: compact ? 15 : 28 * k,
                        fontWeight: FontWeight.w500,
                        letterSpacing: compact ? 1.8 : 3.4 * k,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: compact ? 10 : 14 * k),
              if (compact)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [time, const SizedBox(height: 12), dayWord],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    time,
                    SizedBox(width: 36 * k),
                    Flexible(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 27 * k),
                        child: dayWord,
                      ),
                    ),
                  ],
                ),
              SizedBox(height: compact ? 18 : 20 * k),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Text.rich(
                  TextSpan(children: headline),
                  style: TextStyle(
                    fontSize: compact ? 26 : 50 * k,
                    fontWeight: FontWeight.w500,
                    height: 1.15,
                  ),
                ),
              ),
              if (forecastEnd != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Forecast only runs until ${clockLabel(forecastEnd)}.',
                    style: TextStyle(
                      fontFamily: body,
                      fontSize: compact ? 16 : 20,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // The button's space is kept in every state, so the answer doesn't
        // move when Retry or "Plan for…" comes and goes.
        SizedBox(height: compact ? 20 : 28 * k),
        Visibility(
          visible: action != null,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: action ?? retry,
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SlideIn(
          child: state.status is Failed && state.forecast != null
              ? Padding(
                  key: const ValueKey('stale'),
                  padding: EdgeInsets.only(top: compact ? 16 : 28),
                  child: Wrap(
                    spacing: 20,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        "Couldn't update. Showing the forecast from "
                        '${clockLabel(state.forecast!.fetchedAt)}.',
                        style: TextStyle(
                          fontFamily: body,
                          fontSize: compact ? 15 : 18,
                          fontWeight: FontWeight.w500,
                          color: purple,
                        ),
                      ),
                      // Hidden while it retries; the notice itself stays put.
                      Visibility(
                        visible: !retrying,
                        maintainSize: true,
                        maintainAnimation: true,
                        maintainState: true,
                        child: retry,
                      ),
                    ],
                  ),
                )
              : null,
        ),
        Expanded(
          child: Align(
            alignment: compact ? Alignment.topLeft : Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(top: compact ? 40 : 24),
              child: answer,
            ),
          ),
        ),
      ],
    );
  }
}

/// The start time. Only the glyphs that change roll; while loading it
/// scrambles digits, unless the user asked for reduced motion.
class _BigTime extends StatefulWidget {
  const _BigTime(this.text, {required this.waiting, required this.style});

  final String text;
  final bool waiting;
  final TextStyle style;

  @override
  State<_BigTime> createState() => _BigTimeState();
}

class _BigTimeState extends State<_BigTime> {
  late final _reel = ReelTextController(initialText: widget.text);
  ReelTextProgress? _waiting;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_BigTime old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final animate = !MediaQuery.disableAnimationsOf(context);
    if (widget.waiting && animate) {
      if (_waiting?.isActive != true) {
        _waiting = _reel.startWaiting(
          widget.text,
          waiting: const ReelWaiting.builder(_scramble),
        );
      }
    } else if (_reel.value != widget.text || _waiting?.isActive == true) {
      _reel.set(widget.text); // also stops a waiting loop
    }
  }

  @override
  void dispose() {
    _reel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ReelText.controller(controller: _reel, style: widget.style);
}

/// Rolling digits around a fixed colon, back to "--:--" every fourth tick.
String _scramble(String text, int tick) => tick % 4 == 0
    ? text
    : [
        for (final (i, c) in text.split('').indexed)
          c == ':' ? c : '${(tick * 7 + i * 3) % 10}',
      ].join();

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
    if (state.status case Ready(refreshing: true) || Failed(retrying: true))
      'Updating…',
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
