import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/forecast.dart';
import '../theme.dart';

/// The thin 48-hour line along the first screen's foot (PRD §16): the
/// recommended window is a solid notch, the deadline a dashed purple rule.
/// Slots are placed by time, so a gap in the forecast is a gap in the line.
class IntensityLine extends StatelessWidget {
  const IntensityLine({
    required this.slots,
    this.window,
    this.deadline,
    super.key,
  });

  /// The slots from now on, in time order.
  final List<ForecastSlot> slots;
  final ({DateTime start, DateTime finish})? window;
  final DateTime? deadline;

  @override
  Widget build(BuildContext context) {
    final compact = isCompact(context);
    final height = compact ? 80.0 : 120.0;
    if (slots.isEmpty) return SizedBox(height: height);
    final start = slots.first.from;
    final span = slots.last.to.difference(start).inMinutes.toDouble();
    double x(DateTime t) => t.difference(start).inMinutes.toDouble();
    final top = slots.map((s) => s.intensity).reduce(math.max).toDouble();

    final spots = [
      for (final (i, s) in slots.indexed) ...[
        if (i > 0 && slots[i - 1].to != s.from) FlSpot.nullSpot,
        FlSpot((x(s.from) + x(s.to)) / 2, s.intensity.toDouble()),
      ],
    ];
    // Hard colour stops turn the line Cobalt Green inside the notch.
    final window = this.window;
    final inNotch = window == null
        ? null
        : [
            x(window.start) / span,
            x(window.finish) / span,
          ].map((v) => v.clamp(0.0, 1.0)).toList();

    return Semantics(
      image: true,
      label:
          'Grid carbon intensity for the next 48 hours, with the recommended '
          'window marked',
      child: SizedBox(
        height: height,
        child: LineChart(
          duration: motion(context, 250),
          LineChartData(
            minX: 0,
            maxX: span,
            minY: -0.1 * top,
            maxY: 1.1 * top,
            titlesData: const FlTitlesData(show: false),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            lineTouchData: const LineTouchData(enabled: false),
            rangeAnnotations: RangeAnnotations(
              verticalRangeAnnotations: [
                if (window != null)
                  VerticalRangeAnnotation(
                    x1: x(window.start),
                    x2: x(window.finish),
                    color: slate,
                  ),
              ],
            ),
            extraLinesData: ExtraLinesData(
              verticalLines: [
                if (deadline case final d?)
                  VerticalLine(
                    x: x(d),
                    color: purple,
                    strokeWidth: compact ? 2.5 : 3,
                    dashArray: [6, 5],
                  ),
              ],
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                barWidth: compact ? 2 : 3,
                dotData: const FlDotData(show: false),
                color: inNotch == null ? slate : null,
                gradientArea: LineChartGradientArea.wholeChart,
                gradient: inNotch == null
                    ? null
                    : LinearGradient(
                        colors: const [
                          slate,
                          slate,
                          cobalt,
                          cobalt,
                          slate,
                          slate,
                        ],
                        stops: [
                          0,
                          inNotch[0],
                          inNotch[0],
                          inNotch[1],
                          inNotch[1],
                          1,
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
