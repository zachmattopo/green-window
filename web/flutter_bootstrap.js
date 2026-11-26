{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    // GitHub Pages can't send COOP/COEP headers, so skwasm runs
    // single-threaded (checked in Phase 0). That's fine for one module.
    suppressMultithreadingWarning: true,
  },
});
