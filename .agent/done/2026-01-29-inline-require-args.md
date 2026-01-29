# Inline require_args into preflight_deps

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

Maintained according to: .agent/PLANS.md

## Purpose / Big Picture

The `require_args` helper was introduced to validate argument counts, but it is now only used by the `preflight_deps` function inside `scripts/lib.sh`. Maintaining a helper for a single call site adds surface area without any reuse. After this change, `preflight_deps` will perform its own argument-count check and the `require_args` helper will be removed. This keeps behavior identical (same usage message, same exit code) while simplifying the helper API.

## Progress

- [x] (2026-01-29 06:10Z) Inline the argument-count check into `preflight_deps` and remove `require_args`.
- [x] (2026-01-29 06:10Z) Update documentation references and verify static Bash checks.

## Surprises & Discoveries

- Observation: `require_args` is only used by `preflight_deps`.
  Evidence: `rg "require_args" -n` shows a single call in `scripts/lib.sh` plus the helper definition.

## Decision Log

- Decision: Remove `require_args` and inline its logic in `preflight_deps`.
  Rationale: Reduces helper surface area without changing behavior.
  Date/Author: 2026-01-29 / Codex

## Outcomes & Retrospective

`require_args` has been removed and `preflight_deps` now performs its own argument validation. Documentation was updated and static Bash checks pass.

## Context and Orientation

`scripts/lib.sh` hosts shared helpers. The `preflight_deps` function now lives in `scripts/lib.sh` and handles dependency installation for the Ralph loop. `require_args` was added solely to enforce the preflight usage check, and no other scripts call it. The goal is to keep the usage check inside `preflight_deps` and remove the unused helper.

## Plan of Work

Replace the `require_args` call in `preflight_deps` with an inline argument-count check that logs the same usage message and exits with status 1. Remove the `require_args` function from `scripts/lib.sh`. Update `ARCHITECTURE.md` to remove the mention of `require_args` in error handling. Verify with static Bash checks.

## Concrete Steps

Work from the repo root.

1. Edit `scripts/lib.sh`:
   - Replace `require_args 2 "$#" "Usage: preflight-deps.sh <target-dir> <run-dir>"` inside `preflight_deps` with an inline `if [[ "$#" -lt 2 ]]; then ... exit 1; fi` block that logs the exact same message.
   - Remove the `require_args` function definition.
2. Update `ARCHITECTURE.md` to remove the mention of `require_args` from the error-handling section.
3. Run static Bash syntax checks.

## Validation and Acceptance

Acceptance is met when all of the following are true:

- `rg "require_args" -n` returns no matches.
- `rg "Usage: preflight-deps.sh" -n scripts/lib.sh` still shows the same usage message within `preflight_deps`.
- `bash -n scripts/lib.sh` completes with exit code 0.

Milestone verification workflow:

1. Tests to write: none. This is a shell refactor validated via static checks.
2. Implementation: perform the edits described above.
3. Verification: run the commands listed in the acceptance criteria and confirm output/exit codes.
4. Commit: after verification passes, commit with a message like `Milestone 1: inline require_args`.

## Idempotence and Recovery

These edits are safe to apply more than once because they only move a small guard check. If behavior changes unexpectedly, reintroduce `require_args` with its previous implementation and re-run static checks to isolate the issue.

## Artifacts and Notes

    rg "require_args" -n
    (no matches)

    bash -n scripts/lib.sh

## Interfaces and Dependencies

`scripts/lib.sh` must no longer expose `require_args`; `preflight_deps` should perform its own argument validation.

Plan update note: Marked progress complete and recorded verification artifacts after inlining the argument check.
