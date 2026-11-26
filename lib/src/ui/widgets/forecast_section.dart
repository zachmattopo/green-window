import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/forecast.dart';
import '../../domain/london_time.dart';
import '../../domain/window_finder.dart';
import '../theme.dart';

/// The run the outcome recommends, if any.
({DateTime start, DateTime finish})? windowOf(WindowOutcome outcome) =>
    switch (outcome) {
      Wait(:final best) => (start: best.start, finish: best.finish),
      StartNow(:final now) => (start: now.start, finish: now.finish),
      _ => null,
    };

/// The ready-by time the outcome couldn't meet, if any.
DateTime? deadlineOf(WindowOutcome outcome) =>
    outcome is NotEnoughTime ? outcome.deadline : null;

/// The slots still to come, from the current one on.
List<ForecastSlot> slotsAhead(Forecast forecast, DateTime now) =>
    forecast.slots.where((s) => s.to.isAfter(now)).toList();

String _day(DateTime t) => weekdayName(t).substring(0, 3);

/// Below the fold (PRD §16): the bar chart, the window and now figures, the
/// dirty stretches, "Forecast updated" and the attribution.
class ForecastSection extends StatelessWidget {
  const ForecastSection({
    required this.forecast,
    required this.outcome,
    required this.now,
    required this.onBack,
    super.key,
  });

  final Forecast forecast;
  final WindowOutcome outcome;
  final DateTime now;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final compact = isCompact(context);
    final slots = slotsAhead(forecast, now);
    final window = windowOf(outcome);
    final deadline = deadlineOf(outcome);

    // Contiguous high or very high stretches.
    final runs = <(ForecastSlot, ForecastSlot)>[];
    for (final (i, s) in slots.indexed) {
      if (!s.index.isDirty) continue;
      final joins =
          i > 0 && slots[i - 1].index.isDirty && slots[i - 1].to == s.from;
      joins ? runs.last = (runs.last.$1, s) : runs.add((s, s));
    }
    String span((ForecastSlot, ForecastSlot) r) {
      final (from, to) = (_day(r.$1.from), _day(r.$2.to));
      final (start, end) = (clockLabel(r.$1.from), clockLabel(r.$2.to));
      return from == to ? '$start–$end $from' : '$start $from–$end $to';
    }

    final big = TextStyle(
      fontSize: compact ? 22 : 28,
      fontWeight: FontWeight.w500,
      height: 1.7,
    );
    final figures = [
      if (window != null)
        Text(
          [
            'Your window',
            '${clockLabel(window.start)} ${_day(window.start)}',
            if (outcome case Wait(:final best)) '${best.average.round()}',
          ].join(' · '),
          style: big,
        ),
      if (slots.isNotEmpty)
        Text('Now · ${clockLabel(now)} · ${slots.first.intensity}', style: big),
      for (final r in runs) Text('High · ${span(r)}', style: big),
      SizedBox(height: compact ? 20 : 24),
      Text(
        'Forecast updated ${clockLabel(forecast.fetchedAt)} · Data: Carbon '
        'Intensity API, National Energy System Operator, CC BY 4.0 · Bands '
        "from NESO's carbon intensity index",
        style: TextStyle(fontSize: compact ? 15 : 20, height: 1.5),
      ),
      SizedBox(height: compact ? 14 : 32),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: onBack,
          style: TextButton.styleFrom(
            foregroundColor: cobalt,
            padding: EdgeInsets.zero,
          ).copyWith(side: focusRing(cobalt)),
          child: Text(
            'BACK TO THE ANSWER ↑',
            style: TextStyle(fontSize: compact ? 17 : 22, letterSpacing: 2),
          ),
        ),
      ),
    ];

    final label = [
      '48-hour forecast, one bar per half-hour, scrollable.',
      if (window != null)
        'Your window is ${clockLabel(window.start)} to '
            '${clockLabel(window.finish)} ${weekdayName(window.start)}.',
      if (runs.isNotEmpty)
        'High or very high: ${runs.map(span).join(', ')}.'
      else
        'No high or very high periods.',
    ].join(' ');

    final chart = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '48-HOUR FORECAST · ${forecast.region.toUpperCase()} · gCO2/kWh',
          style: TextStyle(
            fontSize: compact ? 18 : 26,
            fontWeight: FontWeight.w500,
            letterSpacing: 2,
          ),
        ),
        SizedBox(height: compact ? 16 : 24),
        _Chart(slots: slots, window: window, deadline: deadline, label: label),
        SizedBox(height: compact ? 16 : 20),
        DefaultTextStyle.merge(
          style: TextStyle(fontFamily: body, fontSize: compact ? 14 : 16),
          child: Wrap(
            spacing: compact ? 18 : 28,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const _Key(cobalt, 'Your window'),
              const _Key(greenBlue, 'Moderate or lower'),
              const _Key(purple, 'High or very high', topEdge: true),
              Text(
                compact
                    ? 'Swipe for later hours →'
                    : 'Scroll for later hours →',
                style: const TextStyle(color: greenBlue),
              ),
            ],
          ),
        ),
      ],
    );

    return ColoredBox(
      color: slate,
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: cobalt, fontFamily: condensed),
        child: Padding(
          padding: compact
              ? const EdgeInsets.fromLTRB(20, 40, 20, 32)
              : const EdgeInsets.symmetric(horizontal: 56, vertical: 64),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    chart,
                    const SizedBox(height: 24),
                    const Divider(color: cobalt, thickness: 2, height: 2),
                    const SizedBox(height: 18),
                    ...figures,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: chart),
                    const SizedBox(width: 64),
                    Container(
                      width: 340,
                      padding: const EdgeInsets.only(left: 32),
                      decoration: const BoxDecoration(
                        border: Border(
                          left: BorderSide(color: cobalt, width: 2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: figures,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key(this.color, this.text, {this.topEdge = false});

  final Color color;
  final String text;
  final bool topEdge;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: color,
          border: topEdge
              ? const Border(top: BorderSide(color: cobalt, width: 2))
              : null,
        ),
      ),
      const SizedBox(width: 8),
      Text(text),
    ],
  );
}

/// One bar per half-hour, scrolling sideways from now. Focusable, so the
/// arrow keys scroll it (PRD §16).
class _Chart extends StatefulWidget {
  const _Chart({
    required this.slots,
    required this.window,
    required this.deadline,
    required this.label,
  });

  final List<ForecastSlot> slots;
  final ({DateTime start, DateTime finish})? window;
  final DateTime? deadline;
  final String label;

  @override
  State<_Chart> createState() => _ChartState();
}

class _ChartState extends State<_Chart> {
  final _scroll = ScrollController();
  var _focused = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = isCompact(context);
    final barWidth = compact ? 14.0 : 22.0;
    final gap = compact ? 3.0 : 4.0;
    final height = compact ? 240.0 : 300.0;
    const labels = 26.0;
    final slots = widget.slots;
    final top = math
        .max(
          50,
          (slots.map((s) => s.intensity).fold(0, math.max) / 50).ceil() * 50,
        )
        .toDouble();
    final edge = top * 2 / height; // 2 px, in gCO2/kWh
    final window = widget.window;
    bool inWindow(ForecastSlot s) =>
        window != null &&
        s.to.isAfter(window.start) &&
        s.from.isBefore(window.finish);
    final deadlineAt = switch (widget.deadline) {
      final d? => slots.indexWhere((s) => !s.from.isBefore(d)),
      null => -1,
    };

    final groups = [
      for (final (i, s) in slots.indexed)
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: s.intensity.toDouble(),
              width: barWidth,
              borderRadius: BorderRadius.zero,
              color: inWindow(s) ? cobalt : greenBlue,
              rodStackItems: s.index.isDirty && !inWindow(s)
                  ? [
                      BarChartRodStackItem(0, s.intensity - edge, purple),
                      BarChartRodStackItem(
                        s.intensity - edge,
                        s.intensity.toDouble(),
                        cobalt,
                      ),
                    ]
                  : null,
            ),
          ],
        ),
    ];

    Widget bottomLabel(double value, TitleMeta meta) {
      final from = toLondon(slots[value.toInt()].from);
      final text = from.hour == 0 && from.minute == 0
          ? _day(from).toUpperCase()
          : from.minute == 0 && from.hour.isEven
          ? clockLabel(from)
          : null;
      if (text == null) return const SizedBox.shrink();
      return SideTitleWidget(
        meta: meta,
        child: Text(
          text,
          softWrap: false,
          overflow: TextOverflow.visible,
          style: TextStyle(
            fontSize: compact ? 13 : 14,
            color: from.hour == 0 ? cobalt : greenBlue,
            fontWeight: from.hour == 0 ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      );
    }

    final width = slots.length * (barWidth + gap);
    final bars = SizedBox(
      width: width,
      height: height + labels,
      child: Stack(
        children: [
          BarChart(
            duration: motion(context, 250),
            BarChartData(
              barGroups: groups,
              alignment: BarChartAlignment.start,
              groupsSpace: gap,
              minY: 0,
              maxY: top,
              barTouchData: BarTouchData(enabled: false),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(
                show: true,
                border: const Border(
                  bottom: BorderSide(color: cobalt, width: 2),
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: labels,
                    getTitlesWidget: bottomLabel,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            height: height,
            child: const _DashedRule(color: cobalt, width: 2),
          ),
          if (deadlineAt > 0)
            Positioned(
              left: deadlineAt * (barWidth + gap) - gap / 2 - 1.5,
              top: 0,
              height: height,
              child: const _DashedRule(color: purple, width: 3),
            ),
        ],
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: SizedBox(
            width: 34,
            height: height,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 4; i >= 0; i--)
                  Text(
                    '${(top * i / 4).round()}',
                    style: const TextStyle(fontSize: 14, color: greenBlue),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: RawScrollbar(
            controller: _scroll,
            thumbVisibility: true,
            thumbColor: cobalt,
            thickness: 6,
            radius: const Radius.circular(3),
            child: SingleChildScrollView(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(bottom: 14),
              child: Focus(
                onFocusChange: (f) => setState(() => _focused = f),
                child: Semantics(
                  label: widget.label,
                  child: DecoratedBox(
                    position: DecorationPosition.foreground,
                    decoration: BoxDecoration(
                      border: _focused
                          ? Border.all(color: cobalt, width: 3)
                          : null,
                    ),
                    child: ExcludeSemantics(child: bars),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A dashed vertical rule, for the now and deadline markers: fl_chart's bar
/// chart doesn't draw vertical lines.
class _DashedRule extends StatelessWidget {
  const _DashedRule({required this.color, required this.width});

  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(width, double.infinity),
    painter: _DashPainter(color, width),
  );
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color, this.width);

  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width;
    for (var y = 0.0; y < size.height; y += 11) {
      final end = math.min(y + 6, size.height);
      canvas.drawLine(Offset(width / 2, y), Offset(width / 2, end), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) =>
      old.color != color || old.width != width;
}
