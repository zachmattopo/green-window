# Green Window: implementation plan

Companion to [PRD.md](PRD.md). Each phase is one small PR into `main` (trunk-based), at most about 1,000 added lines excluding `pubspec.lock`. Every PR must pass the checks in [CLAUDE.md](../CLAUDE.md) and add an entry to [AI_LOG.md](AI_LOG.md).

## Stack

| Package | Why it earns its place |
|---|---|
| Flutter 3.50.1 via fvm | Pinned in `.fvmrc`, so every machine and CI builds the same SDK. |
| `material_ui` | The Material library that the 3.50 template uses. |
| `flutter_bloc` | One Cubit for the module: explicit states that are easy to test, and no events needed for a single screen. |
| `http` | One GET endpoint. `MockClient` from `package:http/testing.dart` covers the client tests without extra packages. |
| `shared_preferences` | Persists the last good forecast per area and the last inputs. Async API, works on web. |
| `timezone` | Explicit Europe/London conversion. Dart's `DateTime` only knows UTC and the browser's own zone. |
| `clock` | `clock.now()` everywhere, so tests fix the time with `withClock`. Tiny, from the Dart team. |
| `equatable` | Value equality for states and models, which `bloc_test` relies on. Avoids code generation. |
| `reel_text` | Animated number changes (intensity, % cleaner). Used in Phase 6. |
| `morphnext` | Animated icon changes (appliance, outcome). Used in Phase 6. |
| `bloc_test` (dev) | Concise Cubit state-sequence tests. |
| `mocktail` (dev) | Mocks the repository in Cubit tests. HTTP uses `MockClient` instead. |
| `flutter_lints` (dev) | Template default, plus a few stricter rules in `analysis_options.yaml`. |

Deliberately left out: get_it/injectable (one screen, so constructor injection is enough), freezed/json_serializable (sealed classes and a hand-written parser are short and need no build step), dio (one GET; `http` plus a small retry loop is enough), go_router (no navigation), and a charting package (one bar chart via `CustomPainter`, decided in Phase 6 with the design).

## Architecture

```
lib/
  main.dart                  bootstrap: timezone data, demo mode, wiring, runApp
  src/
    domain/                  pure Dart, no Flutter, no I/O
      appliance.dart         presets and run times
      forecast.dart          ForecastSlot, Forecast (region, slots, fetchedAt)
      postcode.dart          outward-code parsing → sealed PostcodeResult
      london_time.dart       UTC → Europe/London, day labels, next "ready by"
      window_finder.dart     findGreenWindow(...) → sealed WindowOutcome
    data/
      forecast_failure.dart  sealed failures: network, timeout, server, notFound, rateLimited, parse
      forecast_parser.dart   tolerant JSON → Forecast
      carbon_intensity_client.dart   GET, 10 s timeout, retries, status mapping
      forecast_cache.dart    last good forecast per outward code + last inputs
      forecast_repository.dart       client + cache
      demo/                  fixture and fault-injecting http clients
    ui/
      green_window_cubit.dart, green_window_state.dart
      green_window_module.dart and widgets/
assets/fixtures/             saved real API responses (demo mode and tests)
test/                        mirrors lib/src/
```

Data flows one way: UI → Cubit → Repository → Client/Cache. The Cubit calls the pure `findGreenWindow` on the forecast it holds, so changing the appliance or ready-by time recalculates without a request.

## Phases

| # | PR | Adds | Est. lines (src + tests) | Depends on |
|---|---|---|---|---|
| 0 | Setup and planning | Tooling, docs, CI | ~150 + docs | — |
| 1 | Domain logic | §8 of the PRD | ~300 + ~500 | 0 |
| 2 | Data layer | §10 of the PRD | ~300 + ~400 | 1 |
| 3 | State | Cubit, persistence | ~250 + ~350 | 2 |
| 4 | Functional UI | §9 states, a11y, unstyled | ~400 + ~250 | 3 |
| 5 | Demo mode and hosting | §12, GitHub Pages | ~150 + ~100 | 4 |
| 6 | Design and motion | Your wireframes, chart, animations | ~600–900 (may split 6a/6b) | 4, design |
| 7 | Docs and QA | README, test plan, limitations | Docs | 5, 6 |

Phases 5 and 6 are independent of each other once Phase 4 is merged.

### Phase 0: setup and planning (`phase-0/setup-and-plan`)
- Web-only Flutter 3.50.1 project via fvm. `.fvmrc` committed, `.fvm/` ignored.
- Latest versions of all packages above, checked with `flutter pub outdated`.
- `analysis_options.yaml`: `flutter_lints` plus stricter rules; `.fvm/` excluded.
- `CLAUDE.md` with the format → analyze → test rule.
- Wasm: there's no project-level setting in 3.50.1, so `--wasm` goes in every build and run path: CI, the deploy job and `.vscode/launch.json`.
- CI (`.github/workflows/ci.yml`) on every PR and push to `main`: format check, `dart analyze --fatal-infos`, `flutter test`, `flutter build web --wasm`. The Flutter version is read from `.fvmrc`.
- Placeholder screen and one smoke test.
- `docs/PRD.md`, this plan, and `docs/AI_LOG.md`.

**Done when:** CI is green, and `fvm flutter build web --wasm` succeeds and runs from a static server without COOP/COEP headers (as on GitHub Pages). The outcome is recorded in the plan.

**Outcome (25 Nov 2026):** served by a plain static server (no COOP/COEP, `crossOriginIsolated == false`), Chrome loads `skwasm.wasm` and `main.dart.wasm`, so the app **runs on Wasm in single-threaded mode**. The only side effect is a console warning. GitHub Pages is fine. Phase 5 sets `suppressMultithreadingWarning: true` in the bootstrap config and documents why.

### Phase 1: domain logic (`phase-1/domain`)
- `postcode.dart`: normalise (trim, uppercase, collapse spaces) → outward code; regex validation; BT/GY/JE/IM → NotCovered.
- `london_time.dart`: `toLondon`, `dayLabel(start, now)`, `nextReadyBy(hh, mm, now)` including clock-change days.
- `window_finder.dart`: candidate windows, gaps, ready-by filter, forecast-end limit, tie-break, baseline, the four outcomes, flat thresholds.
- Fixtures: a saved real 48-hour regional response, and a hand-built forecast spanning 28 March 2027 01:00 (clocks go forward).

**Tests (table-driven):**
- postcodes: full, outward, lowercase, spaces, invalid, BT
- windows: run time not a whole number of slots, gap inside a window, window running past the forecast, deadline too soon, deadline past the forecast, a tie, a flat day, a baseline of 0, a gap at the current slot
- day labels across midnight and across the clock change
- "ready by" on 28 March 2027 and 31 October 2027

**Done when:** every rule in PRD §8 has at least one test that would fail if the rule broke.

### Phase 2: data layer (`phase-2/data`)
- `forecast_parser.dart`: reads `data.shortname` and `data.data[]`; drops invalid slots; anything else unexpected → `ParseFailure`.
- `carbon_intensity_client.dart`: `GET /regional/intensity/{from}/fw48h/postcode/{outcode}`, 10 s timeout, 2 retries (1 s, 2 s) on network, timeout and 5xx; 400 → NotFound, 429 → RateLimited. The delay is injectable, so tests run instantly.
- `forecast_cache.dart`: JSON in `SharedPreferencesAsync`, keyed by outward code, with `fetchedAt`; stores the last inputs.
- `forecast_repository.dart`: `cached(outcode)` and `fetch(outcode)`; a successful fetch writes the cache.
- Check the GY/JE/IM assumption against the live API and update the PRD.

**Tests:** `MockClient` for each row in PRD §10, including the retry count and order, plus a cache round-trip and a corrupt-cache entry, which must be ignored rather than crash.

### Phase 3: state (`phase-3/state`)
- `GreenWindowState`: inputs (outcode, appliance, readyBy) plus a sealed status: Idle, Loading(cached?), Ready(outcome, forecast, fetchedAt, refreshing), Failed(failure, cached?).
- `GreenWindowCubit`: `restore()`, `submitPostcode()`, `selectAppliance()`, `setReadyBy()`, `retry()`. Uses the cache first, then refreshes. Changing the appliance or ready-by time recalculates without a fetch. Refetches if the forecast is over 30 minutes old. **Latest request wins**: each fetch gets an id, and stale completions are ignored.

**Tests (`bloc_test` + `mocktail`):** cold load, cached then fresh, cached then failure, out-of-order responses, invalid postcode (no fetch), recalculation without a fetch, inputs restored.

### Phase 4: functional UI (`phase-4/ui`)
- An unstyled Material module: postcode field (Enter submits), appliance choice, ready-by picker with clear, and result area for every PRD §9 state. A plain-text 48-hour list stands in for the chart until Phase 6.
- A sentence-style Semantics label for the result; visible focus; logical tab order; data attribution.

**Tests (widget):** error → Retry → result; Start-now copy; Not-enough-time → "Plan for tomorrow"; BT message; keyboard submit.

### Phase 5: demo mode and hosting (`phase-5/demo-hosting`)
- `?demo=fixture|slow|error|garbled|offline` swaps in an `http.BaseClient` from `data/demo/`; `fixture` also fixes the clock. A banner shows the active mode.
- `.github/workflows/deploy.yml`: on push to `main`, `flutter build web --wasm --release --base-href /green-window/`, then deploy to GitHub Pages. (You enable Pages → "GitHub Actions" in the repo settings once.)

**Tests:** each demo client produces the expected failure type.

**Done when:** the live URL works in Chrome, Safari and Firefox, and in each demo mode.

### Phase 6: design and motion (`phase-6a/theme-layout`, `phase-6b/chart-motion`)
Blocked on your wireframes.
- Theme and layout from the design.
- 48-hour chart with the window and deadline marked.
- `reel_text` for the percentage and intensity values, `morphnext` for the appliance and outcome icons. Both respect reduce-motion.
- Golden or widget tests for the chart's highlighted range.

### Phase 7: docs and QA (`phase-7/docs`)
- README: what it is and the live link; track and API, and why; architecture and trade-offs; how to run (fvm, `--wasm`); test and QA approach; a manual test plan derived from PRD §9, §10 and §12; known limitations; AI usage (links AI_LOG); screenshots.
- A final pass of the manual test plan on the hosted build.

## Known risks

| Risk | Mitigation |
|---|---|
| GitHub Pages can't set the COOP/COEP headers that multi-threaded Wasm needs | Checked in Phase 0: Wasm runs single-threaded without them, which is plenty for one module. Browsers without WasmGC fall back to the JS build automatically. |
| API down during the interview | Cache, `?demo=fixture`, and recorded screenshots |
| Timezone data size on web | Use the smallest data set that includes Europe/London; measure in Phase 1 |
| Wireframes arrive late | Phases 1–5 don't depend on design |
| Running past the ~4-hour timebox | Phases 1–4 are the core. 5–7 can be trimmed, and the trims recorded in Known limitations. |
