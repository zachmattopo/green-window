import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_10y.dart';

import 'src/data/carbon_intensity_client.dart';
import 'src/data/demo/demo_client.dart';
import 'src/data/forecast_cache.dart';
import 'src/data/forecast_repository.dart';
import 'src/ui/green_window_cubit.dart';
import 'src/ui/green_window_module.dart';

void main() {
  initializeTimeZones();
  final live = http.Client();
  // PRD §12. An unknown mode runs live, with no banner.
  final mode = Uri.base.queryParameters['demo'];
  final demo = demoClient(mode, live);
  final fixture = mode == 'fixture';
  final repository = ForecastRepository(
    CarbonIntensityClient(demo ?? live),
    ForecastCache(SharedPreferencesAsync(), prefix: fixture ? 'demo.' : ''),
  );
  final now = fixture ? () => fixtureCapturedAt : DateTime.now;
  runApp(
    BlocProvider(
      lazy: false, // restore() starts loading before the module first reads it
      create: (_) => GreenWindowCubit(repository, now: now)..restore(),
      child: GreenWindowApp(demoMode: demo == null ? null : mode),
    ),
  );
}

class GreenWindowApp extends StatelessWidget {
  const GreenWindowApp({super.key, this.demoMode});

  final String? demoMode;

  @override
  Widget build(BuildContext context) {
    // PRD §11: a focus ring keyboard users can see; Material's own overlay
    // is too faint on chips. Phase 6 restyles it.
    final focusRing = WidgetStateBorderSide.resolveWith(
      (states) => states.contains(WidgetState.focused)
          ? const BorderSide(width: 3)
          : null,
    );
    return MaterialApp(
      title: 'Green Window',
      theme: ThemeData(
        chipTheme: ChipThemeData(side: focusRing),
        filledButtonTheme: FilledButtonThemeData(
          style: ButtonStyle(side: focusRing),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: ButtonStyle(side: focusRing),
        ),
      ),
      home: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (demoMode != null) _DemoBanner(demoMode!),
              const Expanded(child: GreenWindowModule()),
            ],
          ),
        ),
      ),
    );
  }
}

/// PRD §12: names the demo mode, so it's never mistaken for live data.
class _DemoBanner extends StatelessWidget {
  const _DemoBanner(this.mode);

  final String mode;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          'Demo mode: $mode. This is not live data.',
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.onTertiaryContainer),
        ),
      ),
    );
  }
}
