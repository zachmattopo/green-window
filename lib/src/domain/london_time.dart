import 'package:timezone/timezone.dart' as tz;

// Needs timezone data loaded first (initializeTimeZones in main and tests).
final tz.Location _london = tz.getLocation('Europe/London');

/// Converts an instant to Europe/London wall time.
tz.TZDateTime toLondon(DateTime instant) =>
    tz.TZDateTime.from(instant, _london);

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// "now", "today", "tonight", "tomorrow" or a weekday, relative to [now]
/// (PRD §8.6). A [start] at or before [now] is in the current slot.
String dayLabel(DateTime start, DateTime now) {
  if (!start.isAfter(now)) return 'now';
  final s = toLondon(start);
  final n = toLondon(now);
  final days = DateTime.utc(
    s.year,
    s.month,
    s.day,
  ).difference(DateTime.utc(n.year, n.month, n.day)).inDays;
  return switch (days) {
    0 => s.hour < 18 ? 'today' : 'tonight',
    1 => n.hour >= 18 && s.hour < 6 ? 'tonight' : 'tomorrow',
    _ => _weekdays[s.weekday - 1],
  };
}

/// The Europe/London weekday name of [instant], such as "Friday".
String weekdayName(DateTime instant) =>
    _weekdays[toLondon(instant).weekday - 1];

/// The Europe/London time of [instant] in 24-hour format, such as "03:00".
String clockLabel(DateTime instant) {
  final t = toLondon(instant);
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(t.hour)}:${two(t.minute)}';
}

/// The next [hour]:[minute] in Europe/London strictly after [now], as UTC.
/// A time skipped by the spring clock change moves forward to the next valid
/// time; in autumn the first occurrence after [now] wins.
DateTime nextReadyBy(int hour, int minute, DateTime now) {
  final n = toLondon(now);
  for (var day = n.day; ; day++) {
    var candidate = tz.TZDateTime(_london, n.year, n.month, day, hour, minute);
    // Spring: the package shifts a skipped time a full hour; the next valid
    // time is the moment the clocks jump.
    if (toLondon(candidate).hour != hour) {
      candidate = tz.TZDateTime(_london, n.year, n.month, day, hour + 1);
    }
    // Autumn: the same wall time also happened an hour earlier.
    final earlier = toLondon(candidate.subtract(const Duration(hours: 1)));
    if (earlier.hour == hour &&
        earlier.minute == minute &&
        earlier.isAfter(now)) {
      return earlier.toUtc();
    }
    if (candidate.isAfter(now)) return candidate.toUtc();
  }
}
