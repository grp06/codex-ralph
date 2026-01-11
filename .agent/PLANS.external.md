# ExecPlans for Ralph (External Projects)

This file defines how to write and maintain `EXECPLAN.md` for external target repos. The ExecPlan is the single source of truth for agent loops in the target repo and must stay up to date as work progresses.

## Core rules
- The plan file may live outside the target repo; always use the explicit plan path provided by the runner.
- The target repo is the current working directory. All code changes and git commands must run there.
- Only update the plan file and logs in the runner repo unless explicitly asked to change runner code.
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
