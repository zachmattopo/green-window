import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/appliance.dart';
import '../domain/postcode.dart';
import '../domain/window_finder.dart';
import 'green_window_cubit.dart';
import 'green_window_state.dart';
import 'widgets/result_view.dart';

/// Every half hour of the day, for the ready-by picker (PRD §7).
final _readyByTimes = [
  for (var i = 0; i < 48; i++) (hour: i ~/ 2, minute: i.isOdd ? 30 : 0),
];

/// The module: inputs, the result for each PRD §9 state, and attribution.
/// shortcut: unstyled Material; Phase 6 replaces the look, not the behaviour.
class GreenWindowModule extends StatefulWidget {
  const GreenWindowModule({super.key});

  @override
  State<GreenWindowModule> createState() => _GreenWindowModuleState();
}

class _GreenWindowModuleState extends State<GreenWindowModule> {
  final _postcode = TextEditingController();
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
    final cubit = context.read<GreenWindowCubit>();
    final text = Theme.of(context).textTheme;
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
        builder: (context, state) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Green Window', style: text.headlineMedium),
                const SizedBox(height: 16),
                TextField(
                  controller: _postcode,
                  decoration: InputDecoration(
                    labelText: 'Postcode',
                    hintText: 'RG10 or RG10 9XY',
                    errorText: _postcodeMessage(state.postcodeProblem),
                  ),
                  autocorrect: false,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.search,
                  onSubmitted: cubit.submitPostcode,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    onPressed: () => cubit.submitPostcode(_postcode.text),
                    child: const Text('Find my window'),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Appliance', style: text.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final appliance in Appliance.values)
                      ChoiceChip(
                        label: Text(appliance.label),
                        selected: appliance == state.appliance,
                        onSelected: (_) => cubit.selectAppliance(appliance),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                // Not a FormField: its value is only initial, and restore()
                // sets the ready-by time after the first frame.
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'Ready by'),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<ClockTime?>(
                      value: state.readyBy,
                      isDense: true,
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(child: Text('Any time')),
                        for (final time in _readyByTimes)
                          DropdownMenuItem(
                            value: time,
                            child: Text(_clock(time)),
                          ),
                      ],
                      onChanged: cubit.setReadyBy,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ResultView(state),
                const SizedBox(height: 24),
                Text(
                  'Data: Carbon Intensity API, National Energy System Operator, '
                  'CC BY 4.0',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
