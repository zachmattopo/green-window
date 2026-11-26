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
