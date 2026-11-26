# AI usage log

How AI (Claude Code) was used on this project, and what I kept, changed or rejected. One entry per PR.

## Phase 0: idea, PRD and plan

**Used for**
- Shortlisting keyless APIs from the brief and the public-apis list, and checking each one live: CORS headers from a real browser, response times and data quirks.
- An "LLM council": five AI advisors argued from different angles, reviewed each other anonymously, and a chairman summarised. All five picked the Carbon Intensity idea.
- Drafting the PRD and the phased plan, and scaffolding the project.

**Changed or rejected**
- Rejected the painting-explainer idea: the data says *what* is in a painting, rarely *why*.
- Found the WWF Carbon Gizmo on the API's homepage. Kept the idea but repositioned it around region, appliance run time, a 48-hour look-ahead and a "ready by" deadline, using live data to show where the national widget misleads.
- Cut the AI-drafted test plan, which tested almost every rule, to two unit tests (window finder, parser), following the brief's "a test or two". Dropped bloc_test, mocktail and equatable, which only those extra tests needed.
- Took the council's advice not to bring my usual production stack (get_it, injectable, freezed, drift). It's too heavy for one module.

**Verified by hand:** *(to complete after review)*

## Phase 0 follow-up: plan audit

**Used for**
- An audit of the PRD and plan against the live API, looking for rules that would give wrong advice or can't be tested.

**Kept** (9 of 12 findings)
- Unknown postcodes: the live API returns HTTP 200 with `null`, not 400, so the PRD's "400 No postcode match" was wrong. Checked BT/GY/JE (`null`) and IM (returns North West England), so all four are blocked in the app.
- The "now" window starts at now, not at the start of its slot. Otherwise a deadline can be missed by up to 29 minutes.
- Changed the Start now copy from "Start whenever suits you" to "Start now…". "Whenever" was wrong when later windows are dirtier, or when a deadline is set.
- Defined the outcomes for gaps with no window, and for no baseline, and fixed the order they're checked in.
- Recalculates every minute and when the tab becomes visible again, so a start time that has passed is never shown.
- Moved day labels and clock-change deadlines into Test 1's table, because the frozen-clock demo can't reach them by hand.
- No retry on a timeout (the worst case was 33 s). `?demo=slow` delays only the first request, so the race can be seen. Added `?demo=busy` for 429.
- Dropped `clock` and `withClock` for an injected `now`, since zones break the fixture demo if the binding starts outside them.

**Not taken (for now)**
- Removing `reel_text`, `morphnext` and `fl_chart` until Phase 6, a smaller cache, and replacing `timezone` with a hand-written UK rule. Left for Phase 6, or not needed at this scale.

## Phase 0 follow-up: design direction and wireframes

**Used for**
- The Impeccable design skill: a product brief (`PRODUCT.md`), three wireframe directions to choose from, and then wireframes for every PRD §9 state, desktop and mobile, in a Claude Design canvas.
- Finding Sanzo Wada colour combinations with a green that could fill the first screen, and checking their contrast ratios with a script.
- Checking what `reel_text` can animate: any glyph, so the start time and the day word can both roll.

**Changed or rejected**
- Chose the "tide table" direction over a station departure board and a Crouwel-style grid.
- Removed the tide wording ("Next low water"): it made the tide sound like the reason the grid was cleaner. Copy now names the real thing.
- Swapped the first palette (Blue Violet ground) for a green one, because the product is called Green Window. Compared no. 271 with no. 290 and kept no. 271: its ink contrast is 12.9:1, against 6.8:1, and no. 290's dirty-hours colour almost disappears on its own dark ground.
- Pomegranite Purple fails contrast on the dark ground (2.5:1), so the bars below the fold use Green Blue and Cobalt Green only.

**Verified by hand:** *(to complete after review)*

**Design review follow-up**
- Feedback: the chart bars were too thin, and the purple for dirty hours was missing. Bars are now 22 px (14 px on mobile), and the chart scrolls sideways.
- For "dirty" I didn't invent a threshold. The API's own `intensity.index` uses NESO's fixed bands, and high or very high now means dirty, checked live across four regions. That needed one parser field, which is in the PRD (§8.1) and plan (Phase 2). Purple fails contrast on the dark ground, so dirty bars get a Cobalt Green top edge rather than moving purple off them.

## Phase 1: domain logic

**Used for**
- Writing `postcode.dart`, `london_time.dart`, `window_finder.dart` and the table-driven `window_finder_test.dart` from PRD §8.
- Probing `package:timezone` on clock-change days before relying on it, and saving a live RG10 forecast as the fixture.

**Changed or rejected**
- The finder compares integer sums, not averages, so ties and the 10% / 10 g thresholds are exact rather than subject to floating-point error.
- `nextReadyBy` fixes two clock-change cases itself. In autumn `TZDateTime` always picks the second 01:30, so it checks the first. In spring it shifts a skipped 01:30 to 02:30 BST, not 02:00, which would let a window finish 30 minutes past the deadline.
- A self-review found the earliest finish ignored gaps (now + run time even when the "now" window spans a gap). It now uses the first gap-free window, as PRD §8.3 says.
- Without a deadline, a "now" run that would finish past the forecast's end gives No forecast instead of crashing on a missing deadline.
- Kept to one test file, as the plan says. Postcode parsing was checked once with a throwaway script, not committed.

**Verified by hand:** *(to complete after review)*

## Phase 2: data layer

**Used for**
- Writing the failures, parser, client, cache and repository from PRD §10, and `forecast_parser_test.dart`.
- Probing the live API: an unrounded `from` (11:17) still returns the 11:00 slot, and an unknown outward code returns 200 with `null`.
- A throwaway `MockClient` script to check retry counts and status mapping, not committed.

**Changed or rejected**
- The cache keeps the raw response body and re-parses it, instead of a `toJson` for `Forecast`. The parser is already tested, so a corrupt or old-format entry just becomes a cache miss.
- Statuses other than 200, 400, 429 and 5xx map to `ParseFailure` with no retry, since retrying a 404 can't help.
- Slots whose times have no UTC offset are dropped: they would parse as browser-local time and shift every recommendation.
- The parser sorts slots by time, because `findGreenWindow` assumes time order.
- `ForecastSlot.index` defaults to `none`, so Phase 1's test helpers didn't change.
- A self-review found that blocked or full browser storage made `localStorage` throw, which turned a good fetch into an error that isn't a `ForecastFailure`. Every cache read and write now treats a storage error as a miss.
- The same review found that a 200 response with no usable slots would replace the last good cached forecast. Empty forecasts are no longer cached.

**Verified by hand:** *(to complete after review)*

## Phase 3: state

**Used for**
- Writing `GreenWindowState` and `GreenWindowCubit` from PRD §9 and §10, and wiring them in `main.dart`.
- A throwaway test (in-memory `shared_preferences`, `MockClient`) for latest-request-wins, stale-on-failure, recalculating without a fetch, and restore. Not committed, as the plan says.

**Changed or rejected**
- Dropped the plan's `Loading(cached?)`: a cached result being refreshed is `Ready(refreshing: true)`, so the two would have overlapped.
- The outcome is derived on the state from the forecast, inputs and `now`, rather than stored and recalculated by hand in each Cubit method. Changing an input or ticking just emits a new state.
- A cached forecast is shown only if `findGreenWindow` finds a window in it for the current appliance (PRD §10, enough future slots); otherwise it's treated as no cache.
- The minute tick skips refetching while a request is in flight. Otherwise a tick during a new search could start a fetch for the old area and win the latest-request race.
- `BlocProvider` is `lazy: false`; by default `restore()` wouldn't run until something reads the Cubit.
- A self-review found that a refresh returning no usable slots replaced a good result with "No forecast" for 30 minutes. It now shows the error with the last good forecast, as the cache already does.

**Verified by hand:** *(to complete after review)*
