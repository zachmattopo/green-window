import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:morphnext/morphnext.dart';

import '../domain/appliance.dart';
import '../domain/london_time.dart';
import '../domain/postcode.dart';
import '../domain/window_finder.dart';
import 'green_window_cubit.dart';
import 'green_window_state.dart';
import 'theme.dart';
import 'widgets/forecast_section.dart';
import 'widgets/intensity_line.dart';
import 'widgets/result_view.dart';
import 'widgets/slide_in.dart';

/// Every half hour of the day, for the ready-by picker (PRD §7).
final _readyByTimes = [
  for (var i = 0; i < 48; i++) (hour: i ~/ 2, minute: i.isOdd ? 30 : 0),
];

/// The module (PRD §16): a first screen with the inputs, the answer and the
/// 48-hour line, and the forecast below the fold.
class GreenWindowModule extends StatefulWidget {
  const GreenWindowModule({super.key});

  @override
  State<GreenWindowModule> createState() => _GreenWindowModuleState();
}

class _GreenWindowModuleState extends State<GreenWindowModule> {
  final _postcode = TextEditingController();
  final _top = GlobalKey();
  final _below = GlobalKey();
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<GreenWindowCubit>();
    // restore() may have brought the area back before this first build.
    _postcode.text = cubit.state.outcode ?? '';
    // PRD §9: recalculate when the tab becomes visible again.
    _lifecycle = AppLifecycleListener(onResume: cubit.tick);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _postcode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<GreenWindowCubit, GreenWindowState>(
      // Reads out a new result or error, but not the minute tick, which moves
      // "the earliest finish" on every minute (PRD §11).
      listenWhen: (before, after) =>
          before.status != after.status ||
          before.appliance != after.appliance ||
          before.readyBy != after.readyBy ||
          before.skippedDeadline != after.skippedDeadline,
      listener: (context, state) {
        if (resultSentence(state) case final sentence?) {
          unawaited(
            SemanticsService.sendAnnouncement(
              View.of(context),
              sentence,
              TextDirection.ltr,
            ),
          );
        }
      },
      child: BlocConsumer<GreenWindowCubit, GreenWindowState>(
        // Shows the restored area without overwriting what the user typed.
        listenWhen: (before, after) => before.outcode != after.outcode,
        listener: (_, state) {
          if (_postcode.text.isEmpty) _postcode.text = state.outcode ?? '';
        },
        builder: (context, state) {
          final compact = isCompact(context);
          final pad = compact ? 20.0 : 54.0;
          final forecast = state.forecast;
          final outcome = state.outcome;
          final shown = forecast != null && outcome != null;
          final footer = TextStyle(
            fontFamily: condensed,
            fontSize: compact ? 14 : 24,
            fontWeight: FontWeight.w500,
            letterSpacing: compact ? 1.1 : 2.4,
          );
          final attribution = Text(
            'Data: Carbon Intensity API, National Energy System Operator, '
            'CC BY 4.0',
            style: TextStyle(fontFamily: body, fontSize: compact ? 13 : 15),
          );
          final top = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(pad, compact ? 20 : 36, pad, 0),
                child: _inputs(context, state, compact),
              ),
              SlideIn(
                child: switch (_postcodeMessage(state.postcodeProblem)) {
                  null => null,
                  final message => Padding(
                    key: ValueKey(message),
                    padding: EdgeInsets.fromLTRB(pad, 10, pad, 0),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        message,
                        textAlign: compact ? TextAlign.start : TextAlign.end,
                        style: TextStyle(
                          fontFamily: body,
                          fontSize: compact ? 16 : 18,
                          fontWeight: FontWeight.w500,
                          color: purple,
                        ),
                      ),
                    ),
                  ),
                },
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: pad),
                child: UpdateNotice(state),
              ),
            ],
          );
          final answer = Padding(
            padding: EdgeInsets.symmetric(horizontal: pad),
            child: ResultView(state),
          );
          final foot = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: compact ? 24 : 40),
              // The foot keeps its height in every state, so the answer above
              // doesn't move when the forecast arrives or goes.
              IntensityLine(
                slots: shown ? slotsAhead(forecast, state.now) : const [],
                window: shown ? windowOf(outcome) : null,
                deadline: shown ? deadlineOf(outcome) : null,
              ),
              Padding(
                // The link's padding sits in the margin, so its text still
                // lines up with the edge.
                padding: EdgeInsets.fromLTRB(pad, 4, pad - 16, 8),
                child: DefaultTextStyle.merge(
                  style: footer,
                  child: Row(
                    children: [
                      Expanded(
                        child: !shown
                            ? attribution
                            : Text(
                                [
                                  'NOW',
                                  compact
                                      ? 'NEXT 48 H'
                                      : 'GRID CARBON INTENSITY, NEXT 48 H',
                                  if (state.status
                                      case Ready(refreshing: true) ||
                                          Failed(retrying: true))
                                    'UPDATING…'
                                  else
                                    'UPDATED ${clockLabel(forecast.fetchedAt)}',
                                ].join(' · '),
                              ),
                      ),
                      Visibility(
                        visible: shown,
                        maintainSize: true,
                        maintainAnimation: true,
                        maintainState: true,
                        child: TextButton(
                          onPressed: () => _scrollTo(_below),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: Text('SEE THE FORECAST ↓', style: footer),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
          // At least a screen tall, growing with its content instead of
          // overflowing. Desktop centres the answer between the inputs and
          // the foot; mobile keeps it under the inputs.
          final hero = Column(
            key: _top,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: compact
                ? [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [top, answer],
                    ),
                    foot,
                  ]
                : [top, answer, foot],
          );
          return LayoutBuilder(
            builder: (context, viewport) => CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: viewport.maxHeight),
                    child: hero,
                  ),
                ),
                if (shown)
                  SliverToBoxAdapter(
                    child: ForecastSection(
                      key: _below,
                      forecast: forecast,
                      outcome: outcome,
                      now: state.now,
                      onBack: () => _scrollTo(_top),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _scrollTo(GlobalKey key) => Scrollable.ensureVisible(
    key.currentContext!,
    duration: motion(context, 450),
    curve: Curves.easeOutCubic,
  );

  /// The wordmark and the three input pills (postcode, appliance, ready by).
  Widget _inputs(BuildContext context, GreenWindowState state, bool compact) {
    final cubit = context.read<GreenWindowCubit>();
    final size = compact ? 20.0 : 28.0;
    final height = compact ? 44.0 : 52.0;
    final text = TextStyle(
      fontFamily: condensed,
      fontSize: size,
      fontWeight: FontWeight.w500,
      color: slate,
    );
    final error = state.postcodeProblem != null;
    OutlineInputBorder outline(double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(999),
      borderSide: BorderSide(color: error ? purple : slate, width: width),
    );
    // The stadium clips the dropdown's ink, so hover and focus fill the pill.
    Widget pill(Widget child) => SizedBox(
      height: height,
      child: Material(
        type: MaterialType.transparency,
        shape: const StadiumBorder(side: BorderSide(color: slate, width: 2)),
        clipBehavior: Clip.antiAlias,
        child: DropdownButtonHideUnderline(child: child),
      ),
    );
    final inside = EdgeInsets.symmetric(horizontal: compact ? 14 : 24);
    final arrow = Icon(Icons.arrow_drop_down, color: slate, size: size);

    final pills = [
      SizedBox(
        width: compact ? 170 : 230,
        height: height,
        child: Semantics(
          label: 'Postcode',
          child: TextField(
            controller: _postcode,
            style: text,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: 'Your postcode',
              hintStyle: text.copyWith(color: slate.withValues(alpha: 0.6)),
              contentPadding: EdgeInsets.only(left: compact ? 14 : 20),
              enabledBorder: outline(error ? 3 : 2),
              focusedBorder: outline(3),
              suffixIcon: IconButton(
                tooltip: 'Find my window',
                onPressed: () => cubit.submitPostcode(_postcode.text),
                icon: const Icon(Icons.arrow_forward, color: slate),
              ),
            ),
            autocorrect: false,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              TextInputFormatter.withFunction(
                (_, value) => value.copyWith(text: value.text.toUpperCase()),
              ),
            ],
            textInputAction: TextInputAction.search,
            onSubmitted: cubit.submitPostcode,
          ),
        ),
      ),
      pill(
        DropdownButton<Appliance>(
          value: state.appliance,
          style: text,
          icon: arrow,
          padding: inside,
          borderRadius: BorderRadius.circular(16),
          // Every entry shows the current icon, so the visible one morphs.
          selectedItemBuilder: (_) => [
            for (final appliance in Appliance.values)
              Row(
                children: [
                  AnimatedMorphIcon(
                    icon: _applianceIcon(state.appliance),
                    size: size,
                    color: slate,
                  ),
                  const SizedBox(width: 8),
                  Text(_applianceLabel(appliance)),
                ],
              ),
          ],
          items: [
            for (final appliance in Appliance.values)
              DropdownMenuItem(
                value: appliance,
                child: Text(_applianceLabel(appliance)),
              ),
          ],
          onChanged: (appliance) {
            if (appliance != null) cubit.selectAppliance(appliance);
          },
        ),
      ),
      // Not a FormField: its value is only initial, and restore() sets the
      // ready-by time after the first frame.
      pill(
        DropdownButton<ClockTime?>(
          value: state.readyBy,
          style: text,
          icon: arrow,
          padding: inside,
          borderRadius: BorderRadius.circular(16),
          menuMaxHeight: 420,
          selectedItemBuilder: (_) => [
            for (final time in [null, ..._readyByTimes])
              Center(
                child: Text('Ready by ${time == null ? '—' : _clock(time)}'),
              ),
          ],
          items: [
            const DropdownMenuItem(child: Text('Any time')),
            for (final time in _readyByTimes)
              DropdownMenuItem(value: time, child: Text(_clock(time))),
          ],
          onChanged: cubit.setReadyBy,
        ),
      ),
    ];

    final wordmark = Text(
      'GREEN WINDOW',
      style: TextStyle(
        fontSize: compact ? 20 : 30,
        fontWeight: FontWeight.w700,
        letterSpacing: compact ? 1.2 : 1.8,
      ),
    );
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 14,
      children: [
        wordmark,
        Wrap(spacing: compact ? 8 : 18, runSpacing: 8, children: pills),
      ],
    );
  }
}

String _applianceLabel(Appliance a) {
  final hours = a.runTime.inMinutes / 60;
  return '${a.label} · ${hours == hours.roundToDouble() ? hours.round() : hours} h';
}

IconData _applianceIcon(Appliance a) => switch (a) {
  Appliance.washingMachine => Icons.local_laundry_service,
  Appliance.dishwasher => Icons.restaurant,
  Appliance.tumbleDryer => Icons.dry_cleaning,
  Appliance.evCharge => Icons.ev_station,
};

String _clock(ClockTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// US-4 copy. Null when there's nothing to show.
String? _postcodeMessage(PostcodeResult? problem) => switch (problem) {
  InvalidPostcode() => "That doesn't look like a UK postcode.",
  NotCovered(place: 'Northern Ireland') =>
    "Northern Ireland is on a separate grid, so it isn't covered by this "
        'forecast.',
  NotCovered() =>
    "The Channel Islands and the Isle of Man aren't covered by this forecast.",
  ValidOutcode() || null => null,
};
