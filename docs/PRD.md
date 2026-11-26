# Green Window: product requirements

| | |
|---|---|
| Status | Draft for review |
| Owner | Hafiz (product and engineering) |
| Last updated | 26 November 2026 |
| Design | Direction A, green (Sanzo Wada no. 271). Wireframes: [Green Window wireframes](https://claude.ai/artifact/4LLK8xrWzyZCwNnGqoMVRN). Summary in §16. This document fixes behaviour and copy; the wireframes fix layout and theme. |

## 1. Summary

Green Window is a home-screen module that answers one question: **"When should I start this appliance so it runs on the cleanest electricity, and still finishes when I need it?"**

You enter a postcode, pick an appliance and, optionally, a "ready by" time. It gives one plain answer, such as *"Start at 03:00 tonight. Ready by 05:00. 40% cleaner than starting now."*, backed by the 48-hour regional forecast from the National Grid / NESO Carbon Intensity API.

## 2. Problem

The carbon intensity of GB electricity swings widely within a day and between regions. On 25 November 2026, the forecast for the next 48 hours ranged from 64 to 192 gCO2/kWh nationally. At the same moment it read 374 in South Wales and 0 in South Scotland. Running a washing machine, dishwasher or EV charge at the right time is one of the few no-cost carbon choices a household can make. Nobody does the arithmetic themselves.

## 3. Prior art and how we differ

The API's own homepage embeds WWF's "Carbon Gizmo" widget. It answers *"when is the grid greenest?"*. We answer *"when should I start **this** appliance, **here**, so it's **ready when I need it**?"*

| | WWF Carbon Gizmo | Green Window |
|---|---|---|
| Location | National average only | Your region, from your postcode |
| Time slots | Fixed 2-hour blocks on even hours | Any half-hour start |
| Appliance run time | Ignored | The window is as long as the appliance runs (for example 3 hours for a dishwasher) |
| Look-ahead | 24 hours | Up to 48 hours |
| Deadline | None | Optional "ready by" time |
| Flat days | Always shows a "Plug in" | Says when waiting makes no meaningful difference |

Evidence from 25 November 2026 (live data, captured during discovery):
- South Wales's *best* 2-hour window (157) was worse than the national figure *right now* (170). The national advice misleads someone in Cardiff.
- Nationally, the best 2-hour window in the next 24 hours averaged 100, but waiting until Friday 03:00 averaged 64.
- South Scotland was forecast at 0 for all 48 hours, so there was nothing to optimise.

Smart EV chargers already schedule to a "ready by" time, so users understand the idea. Green Window brings it to appliances that have no smarts at all.

## 4. Users

| Persona | Need |
|---|---|
| **Renter in Cardiff** who does laundry most evenings | "Is tonight better than tomorrow morning, and by how much?" |
| **Commuter with an EV** on a home charger | "Charge for 4 hours, ready by 07:30. When should I start?" |
| **Busy parent** loading the dishwasher after dinner | "Do I run it now or set the delay timer?" |

Out of target: Northern Ireland, which is on a separate grid that the API doesn't cover, and users who want cost (£) optimisation.

## 5. Goals and non-goals

**Goals**
1. Give one clear, correct recommendation in under 3 seconds on a normal connection.
2. Never recommend a window that misses the user's deadline, runs past the forecast or crosses a gap in the data.
3. Never overclaim. We talk about the grid being cleaner, not about the user's personal emissions saving.
4. Keep working when the API is slow, down or returns bad data.
5. Be usable by keyboard and screen reader.

**Non-goals for this version**
- Price or tariff optimisation (for example Octopus Agile).
- Notifications, a phone home-screen widget, or controlling smart plugs.
- Accounts, sync or analytics.
- Northern Ireland, the Channel Islands and the Isle of Man.
- Custom appliance durations (presets only; see §13).

## 6. User stories and acceptance criteria

**US-1 Find my window.** As a user, I enter my postcode and pick an appliance to see when to start it.
- Given a valid GB postcode and "Washing machine (2h)", when I submit, I see a start time, an end time and how much cleaner that is than starting now.
- Times are shown in UK time (Europe/London) whatever my device's time zone.
- The answer names the day relative to now: "now", "today", "tonight", "tomorrow" or a weekday (§8.6).

**US-2 Ready by.** As a user, I can say when it must be finished.
- Given "Ready by 07:00", the recommended window ends at or before the next 07:00.
- If there isn't enough time before then, I'm told so, shown the earliest possible finish, and offered "Plan for 07:00 tomorrow".

**US-3 Honest flat days.** As a user, I'm told when waiting isn't worth it.
- If the best window is less than 10% cleaner than starting now, or less than 10 gCO2/kWh cleaner, I see "Start now. Waiting won't make it meaningfully cleaner."
- I'm never told to start "whenever": later windows can be much dirtier than now, and a later start can miss my ready-by time.

**US-4 Postcode help.** As a user, I get a clear message when my postcode can't be used.
- Full or partial postcodes are accepted in any case and spacing ("rg10 9xy", "RG10").
- A postcode that isn't a UK format gets "That doesn't look like a UK postcode."
- BT postcodes get "Northern Ireland is on a separate grid, so it isn't covered by this forecast."
- GY, JE and IM postcodes get "The Channel Islands and the Isle of Man aren't covered by this forecast." These are blocked in the app, before any request (§15).
- A postcode the API doesn't recognise gets "We couldn't find that postcode area."

**US-5 It remembers me.** My last postcode, appliance and ready-by time are restored when I come back.

**US-6 Works when things break.** If the forecast can't be loaded, I can still see the last good result for my area, marked with when it was fetched, and retry.

**US-7 Context.** I can see the 48-hour forecast for my region with my window highlighted, and when the forecast was last updated. It sits below the fold, reached by scrolling or by "See the forecast" (§16).

## 7. Inputs

| Input | Rules |
|---|---|
| Postcode | Required. Only the outward code (for example "RG10") is sent to the API. The rest of the postcode is never stored or sent. |
| Appliance | One of the presets below. Default: washing machine. |
| Ready by | Optional time of day in 30-minute steps. Default: none. Means "finish by the next time it's this o'clock". |

**Appliance presets**

| Appliance | Assumed run time |
|---|---|
| Washing machine | 2 h |
| Dishwasher | 3 h |
| Tumble dryer | 1 h 30 min |
| EV charge (top-up) | 4 h |

Run times are typical eco-cycle lengths, chosen for this version and listed under Known limitations.

## 8. Recommendation rules

This section is the spec for the domain logic and its tests.

### 8.1 Data
- The API returns half-hour slots in UTC, each with a `from` time, a `to` time and a `forecast` intensity in gCO2/kWh.
- A slot is usable only if `forecast` is a whole number ≥ 0 and `to` is exactly 30 minutes after `from`. Unusable slots are dropped, which leaves a gap.
- The **current slot** is the first slot whose `to` is later than now.
- Each slot also carries `index`, NESO's band for that intensity: `very low`, `low`, `moderate`, `high` or `very high`. The bands are fixed numbers, the same in every region. Seen live on 26 Nov 2026: moderate up to 169, high 171–227, very high from 230, low 25–56, very low up to 23. A slot is **dirty** when its index is `high` or `very high`. The index only colours the chart (§16) and never changes the recommendation. A missing or unknown index keeps the slot, which is then not marked dirty.

### 8.2 Candidate windows
- A window is `n` consecutive usable slots, where `n` = the appliance run time divided by 30 minutes, **rounded up**.
- Slots are consecutive only if each one's `from` equals the previous one's `to`. A window never spans a gap.
- Candidate windows start at the current slot (shown as "now") or at any later slot start.
- A window must end on or before the end of the last usable slot, so it never runs past the forecast.
- A window's **finish** is its start plus the appliance run time. The window in the current slot starts **now**, not at the slot's start, so its finish is now + run time. For example, at 04:55 a 2-hour wash in the 04:30 slot finishes at 06:55, not 06:30. The deadline check (§8.3), the "Ready by" time shown and the earliest finish all use the finish.

### 8.3 Ready by
- "Ready by HH:MM" becomes the next HH:MM in Europe/London strictly after now, using real wall-clock time. On clock-change days:
  - March: 01:00 and 01:30 don't exist, so both become 02:00.
  - October: 01:00 and 01:30 happen twice, so the **first** one is used (the earlier deadline, so it's never missed).
- Only windows whose finish (§8.2) is at or before that deadline are candidates.
- If the deadline is later than the end of the forecast, the forecast end is used instead and the answer says "Forecast only runs until {time}".
- If gap-free windows exist but none finishes by the deadline, the result is **Not enough time**, with the earliest possible finish: the finish of the earliest gap-free window.

### 8.4 Choosing
- Score = the average `forecast` across the window's slots.
- Pick the lowest score. On a tie, pick the **earliest** window, so it's ready sooner.
- **Baseline** = the score of the window starting at the current slot. If that window is invalid (a gap or not enough data), there is no baseline: the outcome is Wait, without the "{p}% cleaner" part.

### 8.5 Outcome types

Checked in this order; the first that matches wins.

| Outcome | When | Headline copy |
|---|---|---|
| **No forecast** | No gap-free window of the appliance's length exists anywhere in the forecast, whatever the deadline | "There isn't enough forecast data to plan this right now." Action: Retry. |
| **Not enough time** | A ready-by time is set, gap-free windows exist, and none finishes by the deadline | "There isn't time to finish before {deadline}. The earliest finish is {time}." Action: "Plan for {deadline} tomorrow". |
| **Wait** | There is no baseline, or best ≠ baseline and the saving is ≥ 10% and ≥ 10 gCO2/kWh | "Start at {time} {day}. Ready by {end}. {p}% cleaner than starting now." With no baseline, the last sentence is left out. |
| **Start now** | Otherwise: the best window is the baseline, or the saving is below either threshold | "Start now. Waiting won't make it meaningfully cleaner." |

The percentage is `(baseline − best) / baseline`, rounded down to a whole number. If the baseline is 0, the outcome is always Start now. Copy says "cleaner", never "you'll save X kg" or "halve your emissions", because the forecast is average grid intensity, not the marginal emissions of the user's appliance.

### 8.6 Day labels (Europe/London, relative to now)
- Starts in the current slot → "now".
- Same date, starting before 18:00 → "today".
- Same date, starting at 18:00 or later → "tonight".
- Next date before 06:00, when now is 18:00 or later → "tonight".
- Next date otherwise → "tomorrow".
- Later dates → weekday name ("Friday").

Times are shown in 24-hour format ("03:00"), and the weekday is always available to screen readers.

## 9. States

| State | What the user sees |
|---|---|
| First visit | Empty postcode field, washing machine selected, short explainer |
| Loading (no cache) | Progress indicator; inputs stay editable |
| Loading (cache for this area exists) | Cached result immediately, marked "Updating…" |
| Result | The outcome from §8.5, the region name, "Forecast updated {HH:MM}", and the 48-hour chart |
| Error with cache | Cached result plus "Couldn't update. Showing the forecast from {HH:MM}." and Retry |
| Error without cache | Error message specific to the cause (§10), plus Retry |
| Postcode problem | Inline field message from US-4; no request is sent |

Changing the appliance or the ready-by time recalculates from the forecast already loaded, without a new request. Only a new postcode, Retry, or a forecast older than 30 minutes triggers a fetch.

While the module is open, the result is recalculated every minute and whenever the tab becomes visible again, so it never shows a start time that has already passed. The same check fetches again when the forecast is older than 30 minutes.

## 10. Resilience requirements

| Situation | Behaviour |
|---|---|
| Slow response | Time out after 10 s. No retry, since a retry would keep the user waiting up to 33 s. Fail with "Couldn't reach the forecast service." |
| Network failure or 5xx | Retry up to 2 times, after 1 s and then 2 s. Then fail with "Couldn't reach the forecast service." |
| Unknown postcode: HTTP 200 with the body `null`, or `data` set to `null` | No retry. "We couldn't find that postcode area." (Checked live on 26 Nov 2026: the API doesn't send 400 for a well-formed outward code it doesn't know.) |
| 400 (badly formed outward code) | No retry. "That doesn't look like a UK postcode." Rare, since the app checks the format first. |
| 429 | No retry. "The forecast service is busy. Try again in a minute." |
| Malformed JSON or unexpected shape | No retry. Treat as a failure: "The forecast service sent something we couldn't read." Never crash. |
| Some bad slots | Drop them (§8.1) and carry on with what's valid. |
| Two quick searches | Only the latest request's result is shown. |
| Cached data | Last good forecast per outward code, with its fetch time. Used only while it still has enough future slots for the appliance. |

## 11. Non-functional requirements

- **Platform:** Flutter Web compiled to WebAssembly, falling back to JavaScript where Wasm isn't available. Desktop and mobile browsers. Hosted on GitHub Pages.
- **Accessibility:** every control is reachable and operable by keyboard; Enter submits; the result has a single Semantics label that reads as a sentence; animations respect the "reduce motion" setting; text contrast meets WCAG AA (design).
- **Privacy:** no accounts, cookies or analytics. Only the outward code leaves the device. Inputs and the cache are kept in browser storage.
- **Attribution:** "Data: Carbon Intensity API, National Energy System Operator, CC BY 4.0" visible in the module.
- **Performance:** with a cached forecast, the result shows without waiting for the network. Timezone data is limited to what Europe/London needs, where the package allows it.

## 12. Demo and QA support

For a reliable live demo and manual testing, a `demo` URL parameter swaps the network layer:

| `?demo=` | Behaviour |
|---|---|
| `fixture` | Serves a saved real response and fixes the clock to its capture time |
| `slow` | Adds a 12 s delay to the **first** request only, so it times out. A second search made straight after finishes first, which shows that only the latest request's result is shown. |
| `busy` | Returns HTTP 429 |
| `error` | Returns HTTP 500 |
| `garbled` | Returns invalid JSON |
| `offline` | Throws a network error |

A visible banner names the active demo mode, so it can never be mistaken for live data.

## 13. Success criteria

These map to the brief's grading:
- Two unit tests cover the logic that would do the most damage if it broke: the window finder (gaps, deadlines, flat days) and the forecast parser (bad payloads). Everything else is in the manual test plan.
- Every row in §9 and §10 can be reproduced from the manual test plan using §12.
- The README covers why this API, the architecture and its trade-offs, the test and QA approach, the manual test plan, known limitations and an AI usage log.
- The live demo works from the hosted URL, with `?demo=fixture` as a fallback.

## 14. Later (deliberately out of scope)

Custom durations, notifications when the window opens, a phone home-screen widget, tariff price overlays, smart-plug scheduling, and a "good drying day" weather overlay.

## 15. Assumptions and open questions

- **Assumption:** the 10% / 10 gCO2/kWh "meaningful difference" thresholds are a product judgement and will be tuned against real data in Phase 1.
- **Checked (26 Nov 2026):** BT, GY and JE outward codes return HTTP 200 with the body `null`. IM returns North West England's forecast, which is wrong for the Isle of Man's own grid. So the app blocks all four before sending a request (US-4).
- **Decided (26 Nov 2026):** layout, theme and chart style, in §16 and the wireframes. **Still open:** motion beyond `reel_text`, and the final typeface (Barlow Condensed in the wireframes).

## 16. Design

Wireframes for every §9 state, desktop (1440 × 900) and mobile (390 × 844): [Green Window wireframes](https://claude.ai/artifact/4LLK8xrWzyZCwNnGqoMVRN). The direction contract that Phase 6 builds against is in `.impeccable/surfaces/lib-src-ui-green-window-module-dart.md`, and the product context is in `PRODUCT.md`.

- **Surface:** a standalone page at its own URL, desktop-first. Mobile stacks the same parts.
- **One answer first:** the first screen holds the inputs and the recommendation only. The start time and day word are set very large with `reel_text`. The §8.5 headline sits beneath. A thin 48-hour intensity line runs along the bottom edge, with the window cut into it as a solid notch.
- **Context on demand:** these sit below the fold:
  - the bar chart
  - the window and starting-now figures
  - the high or very high stretches
  - "Forecast updated"
  - the attribution
- **Chart:** one bar per half-hour (22 px on desktop, 14 px on mobile) with 2-hour time labels and the day name at midnight. It starts at now and scrolls sideways for the rest of the 48 hours. It can be scrolled with the keyboard, and the chart has one sentence-style label for screen readers.
- **Colour (Sanzo Wada no. 271):**
  - The first screen is Cobalt Green `#94ff94` with Deep Slate Green `#0f261f` ink (12.9:1). The area below the fold is Deep Slate Green.
  - Chart bars are coloured by the §8.1 index. Moderate or lower is Green Blue `#2dbc94`. Dirty (high or very high) is Pomegranite Purple `#b90078` with a 2 px Cobalt Green top edge, because purple alone is 2.5:1 on the dark ground. The recommended window is the only Cobalt Green bar.
  - Pomegranite Purple also marks the "% cleaner" figure, the ready-by deadline and field errors.
- **Copy:** names the real thing ("Cleanest time to start", "Grid carbon intensity"), never a metaphor that could read as the cause. Headlines and errors come from §8.5, §9 and §10 unchanged. Three pieces of wireframe copy aren't in this PRD yet: the first-visit explainer, the section labels and the demo banner text. They're proposals to confirm in Phase 6.
- The forecast in the wireframes is synthetic, shaped like a real day.
