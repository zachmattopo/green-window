import 'package:flutter_test/flutter_test.dart';
import 'package:green_window/src/domain/appliance.dart';
import 'package:green_window/src/domain/forecast.dart';
import 'package:green_window/src/domain/window_finder.dart';
import 'package:timezone/data/latest_10y.dart';

const _halfHour = Duration(minutes: 30);
final t0 = DateTime.utc(2026, 11, 26, 20); // GMT, so UTC is London time.
DateTime at(int slot) => t0.add(_halfHour * slot);
DateTime utc(int y, int mo, int d, int h, [int mi = 0]) =>
    DateTime.utc(y, mo, d, h, mi);

/// Consecutive half-hour slots from [start]; a null leaves a gap.
Forecast forecast(List<int?> intensities, {DateTime? start}) => Forecast(
  region: 'Test',
  fetchedAt: t0,
  slots: [
    for (final (i, v) in intensities.indexed)
      if (v != null)
        ForecastSlot(
          from: (start ?? t0).add(_halfHour * i),
          to: (start ?? t0).add(_halfHour * (i + 1)),
          intensity: v,
        ),
  ],
);

Matcher waitAt(DateTime start) =>
    isA<Wait>().having((w) => w.best.start, 'start', start);

Matcher notEnoughTime(DateTime deadline, [DateTime? earliestFinish]) {
  final m = isA<NotEnoughTime>().having(
    (o) => o.deadline,
    'deadline',
    deadline,
  );
  return earliestFinish == null
      ? m
      : m.having((o) => o.earliestFinish, 'earliest finish', earliestFinish);
}

void main() {
  setUpAll(initializeTimeZones);

  final soon = t0.add(const Duration(minutes: 5));

  // Each row is a case where a bug would tell the user a wrong time.
  // All rows use the washing machine: 2 h, so 4 slots.
  final cases = <(String, Forecast, DateTime, ClockTime?, Matcher)>[
    (
      'a gap inside a window is never used',
      forecast([100, 100, 100, 100, 90, 10, 10, null, 10, 10, 10, 100]),
      soon,
      null,
      waitAt(at(8)),
    ),
    (
      'a window that ends after the ready-by time is never picked',
      forecast([200, 200, 200, 200, 150, 150, 150, 150, 10, 10, 10, 10]),
      soon,
      (hour: 0, minute: 0),
      waitAt(at(4)),
    ),
    (
      'the "now" window finishes at now + run time',
      forecast([100, 100, 100, 100, 100, 100], start: utc(2026, 11, 27, 4, 30)),
      utc(2026, 11, 27, 4, 55),
      (hour: 6, minute: 30),
      notEnoughTime(utc(2026, 11, 27, 6, 30), utc(2026, 11, 27, 6, 55)),
    ),
    (
      'a deadline too soon gives Not enough time, with the earliest gap-free '
          'finish',
      forecast([100, null, 100, 100, 100, 100, 100]),
      soon,
      (hour: 21, minute: 0),
      notEnoughTime(at(2), at(6)),
    ),
    (
      'gaps that leave no window give No forecast, even with a deadline',
      forecast([100, 100, null, 100, 100, null, 100]),
      soon,
      (hour: 21, minute: 0),
      isA<NoForecast>(),
    ),
    (
      'a gap in the current window gives Wait without a percentage',
      forecast([100, null, 100, 100, 100, 100]),
      soon,
      null,
      isA<Wait>()
          .having((w) => w.best.start, 'start', at(2))
          .having((w) => w.percentCleaner, 'percent', isNull),
    ),
    (
      'a flat day (8% cleaner) gives Start now, not a fake saving',
      forecast([100, 100, 100, 100, 92, 92, 92, 92]),
      soon,
      null,
      isA<StartNow>().having((o) => o.now.start, 'start', soon),
    ),
    (
      'a 02:00 start seen at 22:00 is labelled "tonight"',
      forecast([...List.filled(8, 200), ...List.filled(4, 50)], start: at(4)),
      at(4),
      null,
      isA<Wait>()
          .having((w) => w.best.start, 'start', at(12))
          .having((w) => w.day, 'day', 'tonight'),
    ),
    (
      'ready by 01:30 on 31 Oct 2027 uses the first 01:30',
      forecast(List.filled(6, 100), start: utc(2027, 10, 30, 23)),
      utc(2027, 10, 30, 23),
      (hour: 1, minute: 30),
      notEnoughTime(utc(2027, 10, 31, 0, 30)),
    ),
    (
      'ready by 01:30 on 28 Mar 2027 becomes 02:00 BST',
      forecast(List.filled(6, 100), start: utc(2027, 3, 27, 23)),
      utc(2027, 3, 27, 23, 10),
      (hour: 1, minute: 30),
      notEnoughTime(utc(2027, 3, 28, 1)),
    ),
  ];

  for (final (name, forecast, now, readyBy, expected) in cases) {
    test(name, () {
      final outcome = findGreenWindow(
        forecast: forecast,
        appliance: Appliance.washingMachine,
        now: now,
        readyBy: readyBy,
      );
      expect(outcome, expected);
    });
  }
}
