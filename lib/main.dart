import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
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
import 'src/ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _focusVisibleOnlyForKeys();
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

/// Like CSS `:focus-visible`: focus fills show after keyboard use, not after
/// a click. Flutter keeps them on mouse clicks on desktop, so a dropdown
/// stayed tinted once its menu closed and handed focus back.
void _focusVisibleOnlyForKeys() {
  final focus = FocusManager.instance;
  GestureBinding.instance.pointerRouter.addGlobalRoute((event) {
    if (event is PointerDownEvent) {
      focus.highlightStrategy = FocusHighlightStrategy.alwaysTouch;
    }
  });
  HardwareKeyboard.instance.addHandler((event) {
    if (event is KeyDownEvent) {
      focus.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    }
    return false; // only watching; the key still reaches the app
  });
}

class GreenWindowApp extends StatelessWidget {
  const GreenWindowApp({super.key, this.demoMode});

  final String? demoMode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Green Window',
      theme: greenWindowTheme(),
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
    final compact = isCompact(context);
    return ColoredBox(
      color: slate,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 20 : 56,
          vertical: compact ? 10 : 12,
        ),
        child: Text(
          'DEMO MODE · ${mode.toUpperCase()} · NOT LIVE DATA',
          style: TextStyle(
            color: cobalt,
            fontSize: compact ? 14 : 18,
            fontWeight: FontWeight.w500,
            letterSpacing: compact ? 1.1 : 1.8,
          ),
        ),
      ),
    );
  }
}
