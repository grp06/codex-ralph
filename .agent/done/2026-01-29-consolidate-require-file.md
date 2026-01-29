# Consolidate require_file_with_hint into require_file

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

Maintained according to: .agent/PLANS.md

## Purpose / Big Picture

The helper `require_file_with_hint` is a thin wrapper used only in `run-ralph.sh` to add a second error line. Maintaining two similar helpers adds surface area without much value. After this change, `require_file` will accept an optional hint parameter and handle both cases. This reduces helper count while preserving the exact error output and exit behavior.

## Progress

- [x] (2026-01-29 05:33Z) Fold `require_file_with_hint` into `require_file` and update call sites.
- [x] (2026-01-29 05:33Z) Update documentation references and verify static Bash checks.

## Surprises & Discoveries

- Observation: `require_file_with_hint` is only used in `run-ralph.sh`.
  Evidence: `rg "require_file_with_hint" -n` matches only `run-ralph.sh` and its definition in `scripts/lib.sh`.

## Decision Log

- Decision: Extend `require_file` to accept an optional hint parameter and remove `require_file_with_hint`.
  Rationale: Reduces helper surface area while keeping error messages identical.
  Date/Author: 2026-01-29 / Codex

## Outcomes & Retrospective

`require_file` now accepts an optional hint, and `require_file_with_hint` has been removed. Call sites were updated, documentation adjusted, and static Bash checks pass.

## Context and Orientation

`scripts/lib.sh` provides shared helper functions for error handling. `require_file_with_hint` logs two error lines and exits when a file is missing. `run-ralph.sh` uses it for missing plan/rules messages, while other scripts use `require_file`. The goal is to consolidate into one helper that supports an optional hint message.

## Plan of Work

Update `require_file` in `scripts/lib.sh` to accept an optional third argument (`hint`). If a hint is provided and non-empty, log it as a second error line before exiting. Remove `require_file_with_hint`. Update `run-ralph.sh` to call `require_file` with the hint argument. Update `ARCHITECTURE.md` to remove references to `require_file_with_hint`. Verify with static Bash checks.

## Concrete Steps

Work from the repo root.

1. Edit `scripts/lib.sh`:
   - Update `require_file` to accept an optional third parameter (`hint`).
   - If `hint` is non-empty, call `log_error "$hint"` before exiting.
   - Remove the `require_file_with_hint` function.
2. Edit `run-ralph.sh` to replace `require_file_with_hint` calls with `require_file` and pass the hint as the third argument.
3. Update `ARCHITECTURE.md` to mention only `require_file` (remove `require_file_with_hint`).
4. Run static Bash syntax checks.

## Validation and Acceptance

Acceptance is met when all of the following are true:

- `rg "require_file_with_hint" -n` returns no matches.
- `rg "require_file" -n scripts/lib.sh run-ralph.sh afk-ralph.sh` shows updated usage and the helper definition.
- `bash -n run-ralph.sh afk-ralph.sh scripts/lib.sh` completes with exit code 0.

Milestone verification workflow:

1. Tests to write: none. This is a shell refactor validated via static checks and unchanged error output.
2. Implementation: perform the edits described above.
3. Verification: run the commands listed in the acceptance criteria and confirm output/exit codes.
4. Commit: after verification passes, commit with a message like `Milestone 1: consolidate require_file helper`.

## Idempotence and Recovery

These edits are safe to apply more than once because they only consolidate helper logic. If behavior changes unexpectedly, reintroduce `require_file_with_hint` with its previous implementation and re-run static checks to isolate the issue.

## Artifacts and Notes

    rg "require_file" -n scripts/lib.sh run-ralph.sh afk-ralph.sh
    scripts/lib.sh:28:require_file() {
    run-ralph.sh:29:require_file "$plans_path" "Missing target rules: $plans_path" "Run ./init-project.sh \"$project_abs\" first."
    run-ralph.sh:30:require_file "$plan_path" "Missing target plan: $plan_path" "Run ./init-project.sh \"$project_abs\" first."
    afk-ralph.sh:31:  require_file "$CONFIG_PATH" "Missing config: $CONFIG_PATH"
    afk-ralph.sh:50:require_file "$PLAN_PATH" "Missing plan: $PLAN_PATH"
    afk-ralph.sh:52:require_file "$RULES_PATH" "Missing rules: $RULES_PATH"
    afk-ralph.sh:54:require_file "$SCHEMA_PATH" "Missing schema: $SCHEMA_PATH"

    bash -n run-ralph.sh afk-ralph.sh scripts/lib.sh

## Interfaces and Dependencies

`scripts/lib.sh` must expose a single `require_file` helper that optionally logs a second hint line when provided. `require_file_with_hint` should no longer exist.

Plan update note: Marked progress complete and recorded verification artifacts after consolidating the file helpers.
