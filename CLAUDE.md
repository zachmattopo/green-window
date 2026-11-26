# Green Window

Flutter Web app (built for Wasm) that tells you when to start an appliance so it runs on the cleanest electricity in your GB region. Data: the National Grid / NESO Carbon Intensity API.

- Product spec: [docs/PRD.md](docs/PRD.md). Phased plan: [docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md).
- Flutter is pinned with fvm (`.fvmrc`, 3.50.1). Always run `fvm flutter …` and `fvm dart …`, never the global SDK.

## Architecture

Three layers under `lib/src/`. Data flows one way: UI → Cubit → Repository → Client/Cache.

- `domain/`: pure logic and models: postcode parsing, London time, and `findGreenWindow`, which picks the cleanest window.
- `data/`: the Carbon Intensity HTTP client (timeouts, retries, failure mapping), a tolerant JSON parser, the `shared_preferences` cache, and the repository that combines them. Demo-mode clients live in `data/demo/`.
- `ui/`: a single `GreenWindowCubit` and the module's widgets. The Cubit runs `findGreenWindow` on the forecast it holds, so changing the appliance or ready-by time doesn't trigger a fetch.

Dependencies are passed in through constructors and wired in `main.dart`. There's no DI container.

## Rule: before ending a response that modified code

Run all three, in this order, every time, even for a one-line change. Fix anything they report before finishing, and state the results in the response.

```bash
fvm dart format .
fvm dart analyze --fatal-infos
fvm flutter test
```

## Conventions

- Trunk-based: one small PR per phase into `main`, at most about 1,000 added lines (excluding `pubspec.lock`).
- `lib/src/domain/` is pure Dart: no Flutter imports, no I/O. That is where the logic and most of the tests live.
- Time is passed in, never read globally. Domain functions take `now` as a parameter. The Cubit gets a `DateTime Function() now` through its constructor. Only `main.dart` passes `DateTime.now`. No `withClock` or zones: they break `?demo=fixture` if Flutter's binding starts outside the zone.
- Every time shown to a user is converted to Europe/London explicitly, never with `toLocal()`.
- No code generation (no freezed, json_serializable or injectable). Use sealed classes and hand-written `fromJson`.
- Add an entry to [docs/AI_LOG.md](docs/AI_LOG.md) in each PR: what AI produced, what was changed or rejected, and why.
