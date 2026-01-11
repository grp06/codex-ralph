# Improve Typing Performance, Experience, and Test Coverage

This ExecPlan is a living document. Keep Progress, Surprises & Discoveries, Decision Log, and Outcomes & Retrospective updated throughout.

Maintained according to: .agent/PLANS.md

## Purpose / Big Picture
Users experience faster, smoother typing with fewer dropped frames or lag, visible responsiveness improvements, and stronger regression safety via tests. We can observe improvements via performance metrics (timings, FPS, or profiler snapshots), UX benchmarks (typing latency, input handling), and a green test suite that covers core typing flows.

## Progress
- [x] (2026-01-11) Audit repo and runtime behavior to identify performance bottlenecks and typing UX issues; capture baseline metrics and pain points.
- [x] (2026-01-11) Draft a concrete improvement plan in this ExecPlan, including a checklist of specific fixes and tests to add.
- [x] (2026-01-11) Implement slice: memoize passage character rendering and add a unit test guarding against timer-driven recomputation.
- [x] (2026-01-11) Implement slice: add IME composition handling with a unit test for keystroke counting.
- [x] (2026-01-11) Implement slice: pause timer updates when the page is hidden and add a visibility-aware unit test.
- [x] (2026-01-11) Implement slice: keep caret pinned to the end during typing to avoid selection jumps, with a unit test.
- [x] (2026-01-11) Implement slice: reduce typing timer cadence to 1s and assert interval setup in the visibility test.
- [ ] (2026-01-11) Implement remaining performance/typing fixes and add/expand tests per the checklist.
- [ ] (2026-01-11) Validate improvements with profiling + test suite; record results and update Outcomes & Retrospective.

## Surprises & Discoveries
- Observation: Typing input and passage rendering live in a single client component with frequent state updates and per-keystroke re-rendering of all characters.
  Evidence: `components/TypingRitual.tsx` builds `passageCharacters` via `targetText.split("").map(...)` on every render and uses `setTypedText`/`setKeystrokesTotal` in `handleChange`.
- Observation: The active timer is a 250ms interval that updates `now` during typing, guaranteeing a render cadence even without input.
  Evidence: `components/TypingRitual.tsx` interval in `useEffect` tied to `startTime` and `isComplete`.
- Observation: The typing timer can be safely paused when `document.visibilityState` is hidden and resumed on `visibilitychange`.
  Evidence: Updated `components/TypingRitual.tsx` timer effect and new unit test `tests/unit/typing-ritual-visibility.test.tsx`.
- Observation: Existing tests cover metrics/locking and some typing ritual behavior, but runtime performance instrumentation is absent.
  Evidence: `tests/unit/typing-metrics.test.ts`, `tests/unit/typing-locking.test.ts`, `tests/unit/typing-ritual-start.test.tsx`; no perf tooling or profiler notes in repo.
- Observation: Unit test listing failed because Jest could not resolve the setup file even though it exists.
  Evidence: `npm run test:unit -- --listTests` -> "Module <rootDir>/jest.setup.ts in the setupFilesAfterEnv option was not found."
- Observation: Jest runs fail before tests execute due to missing Next.js SWC bindings for linux/arm64.
  Evidence: `npm run test:unit -- typing-ritual-memoization.test.tsx` -> "Failed to load SWC binary for linux/arm64".
- Observation: Targeted unit test run still fails before execution due to missing Next.js SWC bindings for linux/arm64.
  Evidence: `npm run test:unit -- typing-ritual-composition.test.tsx` -> "Failed to load SWC binary for linux/arm64".
- Observation: New caret unit test cannot execute because Jest still fails to load Next.js SWC bindings on linux/arm64.
  Evidence: `npm run test:unit -- typing-ritual-caret.test.tsx` -> "Failed to load SWC binary for linux/arm64".

## Decision Log
- Decision: Memoize passage character rendering and add a unit test asserting timer ticks do not trigger recomputation.
  Rationale: Reduces avoidable work on interval-driven renders while giving a regression guard for future changes.
  Date/Author: 2026-01-11 / Codex
- Decision: Defer keystroke counting for IME composition input until composition ends.
  Rationale: Avoids double-counting intermediate composition updates while preserving typed text rendering.
  Date/Author: 2026-01-11 / Codex
- Decision: Pause typing timer updates when the document is hidden, with a unit test to assert visibility gating.
  Rationale: Avoids background render work when the tab is not visible while keeping metrics accurate on return.
  Date/Author: 2026-01-11 / Codex
- Decision: Keep the typing caret pinned to the end during live typing updates.
  Rationale: Prevents selection jumps caused by frequent re-renders of the hidden input.
  Date/Author: 2026-01-11 / Codex
- Decision: Slow the typing timer cadence to 1s and assert the interval duration in the visibility unit test.
  Rationale: The UI only surfaces second-level timing, so 1s ticks reduce render churn without changing displayed precision.
  Date/Author: 2026-01-11 / Codex

## Outcomes & Retrospective
- Outcome: Caret handling now keeps the input selection at the end during active typing, guarded by a new unit test.
- Outcome: Timer cadence reduced to 1s updates to cut render churn; visibility test now asserts the new interval duration.
- What remains: Remaining performance/typing checklist items, plus profiling and full test validation.
- Lessons:

## Context and Orientation
Audit findings:
- Key modules: `components/TypingRitual.tsx` (input handling, render cadence, run persistence), `lib/typing-tests/metrics.ts`, `lib/typing-tests/locking.ts`, `lib/stats/persist.ts`.
- Input handling: `handleChange` updates text and keystroke counts; `handleInputKeyDown` gates typing before countdown and blocks backspace at lock; `window` keydown handler starts countdown on Space/Escape.
- Render cadence: per-keystroke updates re-render the full passage (per-character spans). A 250ms interval updates `now` while typing.
- Baseline metrics: no in-repo instrumentation; profiling/latency baselines require running the app.
- Test coverage: unit tests for metrics/locking and typing ritual start/underline; acceptance tests for typing ritual and stats (`tests/unit/*typing*`, `tests/acceptance/typing-ritual.spec.ts`, `tests/acceptance/stats.spec.ts`).

## Plan of Work
1) Inspect repository structure and identify typing workflow entry points, render loop, and state management.
2) Establish baseline performance metrics and document typing UX issues.
3) Produce a concrete action plan with a checklist of targeted changes and tests.
4) Implement fixes in priority order, keeping changes small and measurable.
5) Add tests to protect improvements and catch regressions.
6) Re-measure performance and finalize documentation in this ExecPlan.

## Checklist (to be filled after audit)
- [ ] Performance: Memoize `passageCharacters` and other derived render data to avoid recomputing on each keystroke.
- [ ] Performance: Replace 250ms timer `now` re-render cadence with RAF or time diff computed only when needed (or pause when idle).
- [ ] Performance: Minimize per-keystroke state updates (batch keystrokes/typed text updates or move counters to refs with a debounced commit).
- [x] Typing UX: Handle composition events (IME) to avoid incorrect keystroke counts and ensure smooth input.
- [x] Typing UX: Prevent focus loss/selection jumps when rendering spans or input updates during typing.
- [ ] Tests: Add unit tests for memoized passage rendering and keystroke batching behavior.
- [ ] Tests: Add integration test for IME composition path (mocked) and verify counts/locking remain correct.
- [ ] Tests: Add acceptance test for typing flow under sustained input to guard against dropped characters.

## Concrete Steps
- Read key docs and entry points (README, app entry, input handling files).
- Run the app locally; use profiling tools to capture baseline latency/FPS or timing metrics.
- Identify hot paths (input processing, rendering, data sync) and list issues with evidence.
- Create a checklist in this ExecPlan with:
  - Performance fixes (e.g., reduce renders, optimize diffing, debounce or batch updates).
  - Typing experience fixes (e.g., input event handling, cursor stability, composition events).
  - Tests to add (unit + integration/e2e), covering typing flows and regressions.
- Implement the checklist items in priority order.

## Validation and Acceptance
- Run existing test suite and newly added tests; all should pass.
- Re-run profiling to confirm measurable improvement vs baseline; document results in Outcomes & Retrospective.

## Idempotence and Recovery
- Each change should be small and independently testable.
- Keep a rollback path by limiting scope per commit and recording baseline metrics for comparison.

## Artifacts and Notes
- Baseline and post-change performance notes (timings, FPS, or profiling screenshots/exports).
- Test logs indicating coverage of typing flows.
- `npm run test:unit -- --listTests` failed with Jest setup file resolution error.
- `npm run test:unit -- typing-ritual-visibility.test.tsx` failed because Next.js SWC bindings were not available for linux/arm64.
- `npm run test:unit -- typing-ritual-visibility.test.tsx` still fails on linux/arm64 due to missing Next.js SWC bindings (logs show failed bindings load).

## Interfaces and Dependencies
- Note any public APIs, event handler signatures, or database schema changes here.
- It is acceptable to use Supabase CLI commands and run migrations locally if needed for this work.
