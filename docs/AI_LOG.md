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
