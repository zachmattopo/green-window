import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_10y.dart';

import 'src/data/carbon_intensity_client.dart';
import 'src/data/forecast_cache.dart';
import 'src/data/forecast_repository.dart';
import 'src/ui/green_window_cubit.dart';
import 'src/ui/green_window_module.dart';

void main() {
  initializeTimeZones();
  final repository = ForecastRepository(
    CarbonIntensityClient(http.Client()),
    ForecastCache(SharedPreferencesAsync()),
  );
  runApp(
    BlocProvider(
      lazy: false, // restore() starts loading before the module first reads it
      create: (_) => GreenWindowCubit(repository, now: DateTime.now)..restore(),
      child: const GreenWindowApp(),
    ),
  );
}

class GreenWindowApp extends StatelessWidget {
  const GreenWindowApp({super.key});

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
      home: const Scaffold(body: SafeArea(child: GreenWindowModule())),
    );
  }
}
