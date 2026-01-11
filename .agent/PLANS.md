# ExecPlans for Ralph

This file defines how to write and maintain `EXECPLAN.md`. The ExecPlan is the single source of truth for agent loops in this repo and must stay up to date as work progresses.

## Core rules
- Keep the plan in the repo root as `EXECPLAN.md`.
- The plan must be self-contained: include all context, definitions, file paths, commands, and expected outputs needed for a new contributor to succeed.
- Start with user-visible outcomes and how to observe them.
- Update Progress, Surprises & Discoveries, Decision Log, and Outcomes & Retrospective whenever anything changes.
- Avoid external links as requirements. If knowledge is needed, write it in the plan.

## Required sections
Every ExecPlan must include these sections:
- Purpose / Big Picture
- Progress (checkbox list with timestamps)
- Surprises & Discoveries
- Decision Log
- Outcomes & Retrospective
- Context and Orientation
- Plan of Work
- Concrete Steps
- Validation and Acceptance
- Idempotence and Recovery
- Artifacts and Notes
- Interfaces and Dependencies

## Progress discipline
- Use checkboxes with a date (YYYY-MM-DD) and optional time.
- Each stopping point must be reflected in Progress. If a task is too large, split it and complete only the first slice.
- The Progress list must always reflect reality.

## Decision and discovery logging
- Decision Log entries must include a rationale and date/author.
- Surprises & Discoveries should include short evidence snippets (command output, logs, or test results).

## Validation and safety
- Include exact commands to run and what success looks like.
- If a step is risky, include a safe retry or rollback path in Idempotence and Recovery.

## ExecPlan template

# <Short, action-oriented goal>

This ExecPlan is a living document. Keep Progress, Surprises & Discoveries, Decision Log, and Outcomes & Retrospective updated throughout.

Maintained according to: .agent/PLANS.md

## Purpose / Big Picture
What user-visible behavior exists when this is done? How do we observe it working?

## Progress
- [ ] (YYYY-MM-DD) Task 1: ...
- [ ] (YYYY-MM-DD) Task 2: ...
- [ ] (YYYY-MM-DD) Task 3: ...

## Surprises & Discoveries
- Observation:
  Evidence:

## Decision Log
- Decision:
  Rationale:
  Date/Author:

## Outcomes & Retrospective
- Outcome:
- What remains:
- Lessons:

## Context and Orientation
What files matter? Current behavior? Any terms that need defining?

## Plan of Work
Concrete narrative of what changes where.

## Concrete Steps
Exact commands to run, and where.

## Validation and Acceptance
What tests to run? What output signals success?

## Idempotence and Recovery
If a step is risky, how to retry/rollback safely?

## Artifacts and Notes
Small snippets (logs, diffs) that prove progress.

## Interfaces and Dependencies
If you are adding public APIs/types, specify names and signatures.
