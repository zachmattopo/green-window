import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_10y.dart';

import 'src/data/carbon_intensity_client.dart';
import 'src/data/forecast_cache.dart';
import 'src/data/forecast_repository.dart';
import 'src/ui/green_window_cubit.dart';

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
    return const MaterialApp(
      title: 'Green Window',
      home: Scaffold(body: Center(child: Text('Green Window'))),
    );
  }
}
