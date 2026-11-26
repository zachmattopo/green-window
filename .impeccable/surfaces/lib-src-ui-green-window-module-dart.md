---
version: 1
slug: "lib-src-ui-green-window-module-dart"
primary_target: "lib/src/ui/green_window_module.dart"
related_targets: []
---

# Green Window page

Scope: the standalone page (one route), visitor mode Operate. Desktop-first at 1440 × 900; mobile adapts.
Task: enter postcode, appliance, optional ready-by; read one recommendation; reveal the forecast only when wanted.

## Direction contract

THESIS: The recommendation is the page. One giant `reel_text` start time on a drenched green screen, with a single forecast line along its foot. Refuses the category default: a dashboard of cards, gauges and a chart competing with the answer.

OWN-WORLD: Sanzo Wada no. 271. First screen ground Cobalt Green #94ff94, ink Deep Slate Green #0f261f (12.9:1). Below the fold the ground flips to Deep Slate Green with Cobalt Green type. Green Blue #2dbc94 for moderate-or-lower bars and placeholder glyphs. Pomegranite Purple #b90078 for dirty bars (API index high or very high, with a 2px Cobalt Green top edge on the dark ground), the "% cleaner" figure, the ready-by deadline and field errors. The chart scrolls sideways, one wide bar per half-hour. The recommended window is the only solid notch on the line and the only Cobalt Green bar in the chart. One condensed grotesk; inputs are outlined capsule pills.

STORY: The user sees when to start, when it'll be ready and how much cleaner, in one glance. They trust it because the line shows the dip it chose. They act, or scroll to check the 48 hours.

FIRST VIEWPORT: Top rule: wordmark left, input pills right (postcode, appliance, ready by). Region label "{REGION} · CLEANEST TIME TO START". Time at ~140px+ with the day word beside it, both `reel_text`. PRD headline sentence beneath. Full-width 48 h intensity line pinned to the bottom edge, window notched, "Now" at left, "See the forecast ↓" at right.

FORM: tide-table direction (grounded list position 5), seed key 9a1f398d. Copy never uses tide words; the line is "Grid carbon intensity, next 48 h".

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

Wireframes for every state, desktop and mobile: https://claude.ai/artifact/4LLK8xrWzyZCwNnGqoMVRN

## Unresolved

Motion beyond `reel_text`; the final typeface (Barlow Condensed in the wireframes); the wireframe-only copy (first-visit explainer, section labels, demo banner).
