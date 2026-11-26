# Green Window: implementation plan

Companion to [PRD.md](PRD.md). Each phase is one small PR into `main` (trunk-based), at most about 1,000 added lines excluding `pubspec.lock`. Every PR must pass the checks in [CLAUDE.md](../CLAUDE.md) and add an entry to [AI_LOG.md](AI_LOG.md).

## Stack

| Package | Why it earns its place |
|---|---|
| Flutter 3.50.1 via fvm | Pinned in `.fvmrc`, so every machine and CI builds the same SDK. |
| `material_ui` | The Material library that the 3.50 template uses. |
| `flutter_bloc` | One Cubit for the module: explicit states, and no events needed for a single screen. |
| `http` | One GET endpoint. |
| `shared_preferences` | Persists the last good forecast per area and the last inputs. Async API, works on web. |
| `timezone` | Explicit Europe/London conversion. Dart's `DateTime` only knows UTC and the browser's own zone. |
| `reel_text` | Animated number changes (intensity, % cleaner). Used in Phase 6. |
| `morphnext` | Animated icon changes (appliance, outcome). Used in Phase 6. |
| `fl_chart` | The 48-hour intensity chart with the window and deadline marked. Used in Phase 6. |
| `flutter_lints` (dev) | Template default, plus a few stricter rules in `analysis_options.yaml`. |

Deliberately left out: get_it/injectable (one screen, so constructor injection is enough), freezed/json_serializable (sealed classes and a hand-written parser are short and need no build step), dio (one GET; `http` plus a small retry loop is enough), go_router (no navigation), and bloc_test, mocktail and equatable (the two tests below are pure functions, so nothing needs mocking or state comparison). Also left out: `clock`. Faking time with `withClock` relies on Dart zones. If Flutter's binding starts outside that zone, tap and frame callbacks read the real time, and `?demo=fixture` quietly breaks. Time is passed in instead (see Architecture).

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
      forecast_failure.dart  sealed failures: network, timeout, server, notFound, invalidPostcode, rateLimited, parse
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

**Time is passed in, never read globally.** Domain functions take `now` as a parameter. The Cubit takes a `DateTime Function() now` in its constructor: `main.dart` passes `DateTime.now`, and `?demo=fixture` passes a function that returns the fixture's capture time. Nothing else calls `DateTime.now()`.

## Testing approach

There are **two unit tests**, one for each way this module could do real damage:

1. **Wrong advice**: `findGreenWindow` (Phase 1). If it breaks, people run appliances at the wrong time, and nothing on screen looks wrong. It also covers the day label and the ready-by conversion around clock changes, because `?demo=fixture` freezes one moment and can't reach those cases by hand.
2. **A bad payload**: the forecast parser (Phase 2). If it breaks, one odd API response takes down the module for every user.

Everything else (retries, caching, races, UI states, copy, chart, demo mode) is checked by hand with the manual test plan in Phase 7, using `?demo=` to reproduce each failure. Those checks are listed in the README as what I'd automate next. There's no coverage target.

## Phases

| # | PR | Adds | Est. lines (src + tests) | Depends on |
|---|---|---|---|---|
| 0 | Setup and planning | Tooling, docs, CI | ~150 + docs | — |
| 1 | Domain logic | §8 of the PRD | ~300 + ~130 | 0 |
| 2 | Data layer | §10 of the PRD | ~300 + ~40 | 1 |
| 3 | State | Cubit, persistence | ~250 | 2 |
| 4 | Functional UI | §9 states, a11y, unstyled | ~400 | 3 |
| 5 | Demo mode and hosting | §12, GitHub Pages | ~150 | 4 |
| 6 | Design and motion | Theme and layout from the wireframes, chart, animations | ~600–900 (may split 6a/6b) | 4, design |
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
- `window_finder.dart`: `findGreenWindow(forecast, appliance, readyBy, now)`, where `readyBy` is a time of day. It converts that time with `nextReadyBy` itself and returns the day label in the outcome, so Test 1 covers both. It handles candidate windows, gaps, the finish of the "now" window (now + run time), the ready-by filter, the forecast-end limit, tie-break, baseline, the four outcomes in PRD §8.5 order, and the flat thresholds.
- Fixture: a saved real 48-hour regional response (also used by demo mode).
- Delete the Phase 0 smoke test, which only checked the placeholder screen.

**Test 1: `window_finder_test.dart`**, a single table-driven test on small hand-built forecasts. Each row is a case where a bug would give the user a wrong time:
- a gap inside a window is never used
- a window that ends after the ready-by time is never picked
- the "now" window finishes at now + run time: at 04:55, a 2 h run in the 04:30 slot misses a 06:30 deadline
- a deadline too soon gives Not enough time, with the earliest gap-free finish
- gaps that leave no window of the right length give No forecast, even with a deadline
- a gap in the current window (no baseline) gives Wait without a percentage
- a flat day gives Start now, not a fake saving
- a 02:00 start seen at 22:00 is labelled "tonight"
- ready by 01:30 on 31 Oct 2027 uses the first 01:30 (00:30 UTC); ready by 01:30 on 28 Mar 2027 becomes 02:00 BST (01:00 UTC)

**Done when:** that test passes. Tie-break and postcode parsing go in the Phase 7 manual test plan.

**Outcome (26 Nov 2026):** the test passes (10 rows: the nine above, with the clock-change row split in two). Timezone data uses `latest_10y` (67 KB, against 258 KB for `latest`). The fixture is `assets/fixtures/forecast_rg10.json` (RG10, South England, 96 slots from 11:00 UTC). On it, every preset gets a Wait about 45–47% cleaner than starting now, so the 10% / 10 g thresholds stay as they are.

### Phase 2: data layer (`phase-2/data`)
- `forecast_parser.dart`: reads `data.shortname`, `data.data[].intensity.forecast` and `intensity.index` (an enum on `ForecastSlot`; missing or unknown → none, never dirty); drops invalid slots. A body of `null`, or `data: null`, → `NotFound`. Anything else unexpected → `ParseFailure`.
- `carbon_intensity_client.dart`: `GET /regional/intensity/{from}/fw48h/postcode/{outcode}`, 10 s timeout and no retry on a timeout. 2 retries (1 s, 2 s) on network errors and 5xx. 400 → InvalidPostcode, 429 → RateLimited. The API returns 200 with `null`, not 400, for a well-formed outward code it doesn't know (checked live on 26 Nov 2026), so the parser handles that case.
- `forecast_cache.dart`: JSON in `SharedPreferencesAsync`, keyed by outward code, with `fetchedAt`; stores the last inputs.
- `forecast_repository.dart`: `cached(outcode)` and `fetch(outcode)`; a successful fetch writes the cache.

**Test 2: `forecast_parser_test.dart`.** A garbled payload gives `ParseFailure`, a `null` body gives `NotFound`, and a response with some bad slots keeps the good ones, and a slot with an unknown index is kept, with no band. Retries, status mapping and the cache are checked by hand with `?demo=`.

**Outcome (26 Nov 2026):** the test passes, including a row that parses the saved RG10 fixture in full (96 slots). The cache stores the raw API body and re-parses it on read, so there's no second serialiser, and a corrupt entry is a cache miss. Retries, timeout and status mapping were checked once with a throwaway `MockClient` script (5xx and network errors: 3 calls; timeout, 400, 429 and other statuses: 1 call). The live API accepts an unrounded `from` and still returns the current slot.

### Phase 3: state (`phase-3/state`)
- `GreenWindowState`: inputs (outcode, appliance, readyBy) plus a sealed status: Idle, Loading(cached?), Ready(outcome, forecast, fetchedAt, refreshing), Failed(failure, cached?).
- `GreenWindowCubit`: `restore()`, `submitPostcode()`, `selectAppliance()`, `setReadyBy()`, `retry()`. Uses the cache first, then refreshes. Changing the appliance or ready-by time recalculates without a fetch. Refetches if the forecast is over 30 minutes old. **Latest request wins**: each fetch gets an id, and stale completions are ignored.
- **Keeps the answer current**: a `Timer.periodic` of 1 minute (cancelled in `close()`) calls `tick()`, which recalculates from the held forecast and refetches if it's over 30 minutes old. The module widget also calls `tick()` when the tab becomes visible again (`AppLifecycleListener.onResume`).

**Tests:** none. Latest-request-wins and stale-on-failure are in the manual test plan (`?demo=slow`: search, then search again straight away; `?demo=error`).

**Outcome (26 Nov 2026):** states are Idle, Loading, Ready(forecast, refreshing) and Failed(failure, stale?). A cached result being updated is `Ready(refreshing: true)`, so Loading carries no cache, and `fetchedAt` comes from the forecast. The outcome is a derived field on the state (inputs + `now`), so input changes and the minute tick only re-emit. A same-area submit, or a restore, with a forecast under 30 minutes old doesn't fetch (PRD §9). The repository passes the last inputs through, so the Cubit only depends on it. `main.dart` now loads timezone data and wires the Cubit (`lazy: false`, so `restore()` runs before Phase 4's UI exists). The tab-resume `tick()` call is left to Phase 4's widget. Latest-request-wins, stale-on-failure, no-fetch recalculation and restore were checked once with a throwaway test, not committed.

### Phase 4: functional UI (`phase-4/ui`)
- An unstyled Material module: postcode field (Enter submits), appliance choice, ready-by picker with clear, and result area for every PRD §9 state. A plain-text 48-hour list stands in for the chart until Phase 6.
- A sentence-style Semantics label for the result; visible focus; logical tab order; data attribution.

**Tests:** none. Every §9 state is in the manual test plan.

**Outcome (26 Nov 2026):** `green_window_module.dart` holds the inputs (appliances as chips, ready-by as a half-hour dropdown whose "Any time" item clears it) and `widgets/result_view.dart` the §9 states and the §8.5/§10 copy. The result is one `Semantics` sentence that adds the weekday after "tonight" or "tomorrow". It's announced when the status or an input changes, not as a live region, which would read "Not enough time" out every minute as its earliest finish moved. "Plan for {deadline} tomorrow" needed a domain change: `findGreenWindow` takes an optional `skippedDeadline` and uses the next ready-by an hour after it, so the repeated 01:30 when the clocks go back is skipped too. That case was checked once with a throwaway test, not committed: it only matters on the autumn clock-change night, so it's left for later test work. The module calls `tick()` on `AppLifecycleListener.onResume`. Material's focus overlay was too faint on chips, so the theme adds a 3 px focus border to chips and buttons. Checked in Chrome on the Wasm build against the live API: postcode errors, a live RG10 result, ready-by recalculation without a fetch, Not enough time and Plan for tomorrow, restore on reload (inputs and cached forecast), and the keyboard order and focus.

### Phase 5: demo mode and hosting (`phase-5/demo-hosting`)
- `?demo=fixture|slow|busy|error|garbled|offline` swaps in an `http.BaseClient` from `data/demo/`. `fixture` also gives the Cubit a fixed `now`. `slow` delays only the first request, so the latest-request-wins race can be seen. `busy` returns 429. A banner shows the active mode.
- `.github/workflows/deploy.yml`: on push to `main`, `flutter build web --wasm --release --base-href /green-window/`, then deploy to GitHub Pages. (You enable Pages → "GitHub Actions" in the repo settings once.)

**Tests:** none. Demo mode is itself a manual QA tool, checked by hand in each mode.

**Done when:** the live URL works in Chrome, Safari and Firefox, and in each demo mode.

**Outcome (26 Nov 2026):** `data/demo/demo_client.dart` returns `http`'s `MockClient` for each mode, or null (live) for none or an unknown one. `fixture` serves the RG10 fixture for any postcode, freezes the clock at 11:00 UTC on 26 Nov 2026, and stores under `demo.` keys so it never reads or overwrites the live cache. `slow` forwards to the live API. `web/flutter_bootstrap.js` sets `suppressMultithreadingWarning: true`. Checked in Chrome on a release `--wasm` build served under `/green-window/` from a plain static server (`crossOriginIsolated == false`, `main.dart.wasm` loaded, no console warning): the banner and the right message in every mode, and in `slow` a second search shows its result and isn't replaced when the first times out. The live URL, Safari and Firefox are still to check once this is merged and Pages is enabled.

### Phase 6: design and motion (`phase-6a/theme-layout`, `phase-6b/chart-motion`)
Built against the [Green Window wireframes](https://claude.ai/artifact/4LLK8xrWzyZCwNnGqoMVRN), PRD §16, and the direction contract in `.impeccable/surfaces/lib-src-ui-green-window-module-dart.md`. Each §9 state has a desktop and a mobile artboard.
- 6a: the theme from Sanzo Wada no. 271 (colour roles in PRD §16). The first screen holds the inputs as capsule pills and the large start time and day word. Below it are the headline, and the 48-hour line with the window notch along the bottom edge. Every §9 state as drawn.
- 6b: the below-the-fold 48-hour bar chart (`fl_chart` inside a horizontal scroll view, starting at now), with the window and deadline marked. Bars are coloured by the API's index: dirty (high or very high) is Pomegranite Purple with a Cobalt Green top edge (PRD §16). `reel_text` for the start time and day word: only the glyphs that change roll, and loading uses its waiting animation. `morphnext` for the appliance and outcome icons. Both respect reduce-motion.
- Barlow Condensed and Barlow are bundled as font assets, not fetched at runtime, so the large time is measured correctly on its first frame. Check that `reel_text` keeps digit widths steady with tabular figures.
- No new tests: the chart and motion are presentation, checked by hand. The window they show is already covered in Phase 1.

### Phase 7: docs and QA (`phase-7/docs`)
- README: what it is and the live link; track and API, and why; architecture and trade-offs; how to run (fvm, `--wasm`); test and QA approach; a manual test plan derived from PRD §9, §10 and §12; known limitations; AI usage (links AI_LOG); screenshots.
- A final pass of the manual test plan on the hosted build.

## Known risks

| Risk | Mitigation |
|---|---|
| GitHub Pages can't set the COOP/COEP headers that multi-threaded Wasm needs | Checked in Phase 0: Wasm runs single-threaded without them, which is plenty for one module. Browsers without WasmGC fall back to the JS build automatically. |
| API down during the interview | Cache, `?demo=fixture`, and recorded screenshots |
| Timezone data size on web | Use the smallest data set that includes Europe/London; measure in Phase 1 |
| Wireframes arrive late | Resolved 26 Nov 2026: wireframes are done (PRD §16). Phases 1–5 don't depend on them. |
| Running past the ~4-hour timebox | Phases 1–4 are the core. 5–7 can be trimmed, and the trims recorded in Known limitations. |
