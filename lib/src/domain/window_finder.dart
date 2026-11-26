import 'appliance.dart';
import 'forecast.dart';
import 'london_time.dart';

/// A time of day in Europe/London, such as a "ready by" time.
typedef ClockTime = ({int hour, int minute});

/// A candidate run. [finish] is [start] plus the run time (PRD §8.2);
/// [average] is the mean gCO2/kWh of its slots.
class GreenWindow {
  const GreenWindow({
    required this.start,
    required this.finish,
    required this.average,
  });

  final DateTime start;
  final DateTime finish;
  final double average;
}

/// The recommendation (PRD §8.5).
sealed class WindowOutcome {
  const WindowOutcome();
}

/// Not one gap-free window of the appliance's length in the forecast.
final class NoForecast extends WindowOutcome {
  const NoForecast();
}

/// No window finishes by [deadline]; [earliestFinish] is the soonest one.
final class NotEnoughTime extends WindowOutcome {
  const NotEnoughTime({required this.deadline, required this.earliestFinish});
  final DateTime deadline;
  final DateTime earliestFinish;
}

/// Starting at [best] is meaningfully cleaner. [day] is its PRD §8.6 label.
/// [percentCleaner] is null when there is no baseline to compare with.
/// [forecastEnd] is set when the deadline was capped to the forecast's end.
final class Wait extends WindowOutcome {
  const Wait({
    required this.best,
    required this.day,
    this.percentCleaner,
    this.forecastEnd,
  });
  final GreenWindow best;
  final String day;
  final int? percentCleaner;
  final DateTime? forecastEnd;
}

/// Waiting makes no meaningful difference; [now] is the run from now.
final class StartNow extends WindowOutcome {
  const StartNow({required this.now, this.forecastEnd});
  final GreenWindow now;
  final DateTime? forecastEnd;
}

const _slot = Duration(minutes: 30);
const _minPercent = 10;
const _minGrams = 10;

/// Picks the cleanest time to run [appliance] (PRD §8), finishing by the next
/// [readyBy] in Europe/London if given. Forecast slots must be usable and in
/// time order; gaps between them are allowed. A [skippedDeadline] (a Not
/// enough time deadline, for "Plan for 07:00 tomorrow") moves the deadline to
/// the next [readyBy] after it.
WindowOutcome findGreenWindow({
  required Forecast forecast,
  required Appliance appliance,
  required DateTime now,
  ClockTime? readyBy,
  DateTime? skippedDeadline,
}) {
  final runTime = appliance.runTime;
  final n = (runTime.inMinutes / _slot.inMinutes).ceil();
  final current = forecast.slots.indexWhere((s) => s.to.isAfter(now));
  if (current == -1) return const NoForecast();
  final ahead = forecast.slots.sublist(current);

  // Sums of every gap-free window, keyed by start index into [ahead].
  final sums = <int, int>{};
  for (var i = 0; i + n <= ahead.length; i++) {
    var sum = ahead[i].intensity;
    var ok = true;
    for (var j = i + 1; j < i + n && ok; j++) {
      ok = ahead[j].from == ahead[j - 1].to;
      sum += ahead[j].intensity;
    }
    if (ok) sums[i] = sum;
  }
  if (sums.isEmpty) return const NoForecast();

  // The window in the current slot starts now, not at the slot's start.
  DateTime startOf(int i) =>
      i == 0 && ahead[0].from.isBefore(now) ? now : ahead[i].from;
  DateTime finishOf(int i) => startOf(i).add(runTime);

  final forecastEnd = ahead.last.to;
  // An hour on, so the repeated 01:30 when the clocks go back is skipped too.
  final skipTo = skippedDeadline?.add(const Duration(hours: 1));
  final from = skipTo != null && skipTo.isAfter(now) ? skipTo : now;
  final deadline = readyBy == null
      ? null
      : nextReadyBy(readyBy.hour, readyBy.minute, from);
  final capped = deadline != null && deadline.isAfter(forecastEnd);
  final limit = deadline == null || capped ? forecastEnd : deadline;

  int? best;
  for (final MapEntry(key: i, value: sum) in sums.entries) {
    if (finishOf(i).isAfter(limit)) continue;
    // Strictly lower, so a tie keeps the earliest window.
    if (best == null || sum < sums[best]!) best = i;
  }
  if (best == null) {
    // Without a real deadline, only a "now" run past the forecast's end fails.
    if (deadline == null || capped) return const NoForecast();
    return NotEnoughTime(
      deadline: deadline,
      earliestFinish: finishOf(sums.keys.first),
    );
  }

  GreenWindow window(int i) => GreenWindow(
    start: startOf(i),
    finish: finishOf(i),
    average: sums[i]! / n,
  );
  final cappedAt = capped ? forecastEnd : null;
  Wait wait({int? percent}) => Wait(
    best: window(best!),
    day: dayLabel(startOf(best), now),
    percentCleaner: percent,
    forecastEnd: cappedAt,
  );

  final baseline = sums[0];
  if (baseline == null) return wait();
  // Integer sums keep the threshold checks exact.
  final saving = baseline - sums[best]!;
  final meaningful =
      best != 0 &&
      baseline > 0 &&
      saving * 100 >= baseline * _minPercent &&
      saving >= _minGrams * n;
  if (!meaningful) return StartNow(now: window(0), forecastEnd: cappedAt);
  return wait(percent: saving * 100 ~/ baseline);
}
