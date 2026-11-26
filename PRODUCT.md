# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

GB households deciding when to run an appliance: a renter doing evening laundry, an EV commuter charging overnight to a ready-by time, a parent loading the dishwasher after dinner. They want one answer fast, not a dashboard. Secondary audience: reviewers opening the hosted demo URL on a laptop, so the standalone page leads desktop-first and adapts to mobile.

## Product Purpose

Answer one question: "When should I start this appliance so it runs on the cleanest electricity in my region, and still finishes when I need it?" Success is one clear, correct recommendation in under 3 seconds, which the user trusts enough to act on.

## Positioning

Regional (from postcode), appliance-length windows at any half-hour start, an optional ready-by deadline, 48-hour look-ahead, and honesty on flat days ("waiting won't make it meaningfully cleaner"). The national-average "plug in now" widgets can't truthfully claim any of these.

## Operating Context

A standalone page at its own URL (GitHub Pages), Flutter Web on Wasm. Used in passing: at the washing machine, after dinner, before bed. Inputs: postcode, appliance preset, optional ready-by time. Remembers the last inputs.

## Capabilities and Constraints

- Behaviour and copy are fixed by docs/PRD.md (§8 outcomes, §9 states, §10 failures). Four outcomes: Wait, Start now, Not enough time, No forecast.
- All times in Europe/London, 24-hour.
- `reel_text` (0.5.1) animates the headline recommendation; `fl_chart` draws the 48-hour chart; `morphnext` animates icons.
- Demo mode banner (`?demo=`) must always be visible when active.
- Attribution line "Data: Carbon Intensity API, National Energy System Operator, CC BY 4.0" is visible.

## Brand Commitments

- Name: Green Window. Visual world otherwise open.
- Palette to be drawn from Sanzo Wada's *A Dictionary of Color Combinations* (sanzo-wada.dmbk.io).
- The design centres on one big, clear recommendation rendered with `reel_text`. Everything else (chart, region detail, forecast time) is progressive: revealed on scroll or behind an expand control, only when the user needs it.
- Green is the primary colour: the first screen's ground is a green from the chosen Sanzo Wada combination.
- Voice: plain, honest, never overclaiming. Says "cleaner", never "you'll save X kg". Visual metaphors stay visual: copy names the real thing (grid carbon intensity, cleanest time to start), never a metaphor that could read as the cause (for example "low water").

## Evidence on Hand

Live API data captured 25–26 Nov 2026 (PRD §2–3). No testimonials, users, or metrics exist; none may be invented.

## Product Principles

1. One answer first. The recommendation is the page; context is earned.
2. Honest over flattering: a flat day says so.
3. Never a wrong time: deadlines and gaps are respected visibly.
4. Works when things break: stale data is shown and labelled, never hidden.

## Accessibility & Inclusion

WCAG AA text contrast; full keyboard operation (Enter submits); the result reads as one sentence to screen readers; all motion (including `reel_text`) respects reduce-motion.
