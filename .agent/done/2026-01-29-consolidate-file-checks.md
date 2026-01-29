# Consolidate file-existence checks into shared helpers

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

Maintained according to: .agent/PLANS.md

## Purpose / Big Picture

Multiple entrypoints perform manual file existence checks using the same pattern: test the file, print a specific error message, and exit. This logic is duplicated across `run-ralph.sh` and `afk-ralph.sh` for config, rules, plan, and schema files. After this change, file-check logic will live in shared helpers in `scripts/lib.sh`, and the entrypoints will call those helpers. This keeps error handling consistent and reduces repeated boilerplate without changing any error messages or behavior.

## Progress

- [x] (2026-01-29 04:51Z) Add shared helpers in `scripts/lib.sh` for file-existence checks with optional hints.
- [x] (2026-01-29 04:51Z) Replace inline checks in `run-ralph.sh` and `afk-ralph.sh` with shared helpers.
- [x] (2026-01-29 04:51Z) Verify static Bash checks and confirm error messages remain unchanged.

## Surprises & Discoveries

- Observation: Both `run-ralph.sh` and `afk-ralph.sh` hand-roll “missing file” checks with similar patterns.
  Evidence: `run-ralph.sh` checks `plans_path`/`plan_path`, while `afk-ralph.sh` checks `$CONFIG_PATH`, `$PLAN_PATH`, `$RULES_PATH`, and `$SCHEMA_PATH` using duplicated `if [[ ! -f ... ]]` blocks.

## Decision Log

- Decision: Introduce `require_file` and `require_file_with_hint` helpers in `scripts/lib.sh` and replace inline checks.
  Rationale: Centralizes error handling without altering output and reduces repeated code across entrypoints.
  Date/Author: 2026-01-29 / Codex

## Outcomes & Retrospective

File-existence checks are now centralized in `scripts/lib.sh` via `require_file` and `require_file_with_hint`. Entry points use the shared helpers, and static Bash checks pass with no errors.

## Context and Orientation

The runner uses Bash entrypoints. `run-ralph.sh` validates that `.agent/PLANS.md` and `.agent/execplans/execplan.md` exist in the target repo, while `afk-ralph.sh` validates `RALPH_CONFIG`, `RALPH_RULES`, `RALPH_PLAN`, and `RALPH_SCHEMA` before running. Both scripts source `scripts/lib.sh`, which is the right place for shared helper functions. The goal is to move the repeated file-check pattern into shared helpers while preserving the exact error messages and exit behavior.

## Plan of Work

Add two helpers to `scripts/lib.sh`:

- `require_file <path> <message>`: logs the message and exits 1 if the file does not exist.
- `require_file_with_hint <path> <message> <hint>`: same as above, but prints a second line with the hint before exiting.

Replace the inline checks in `run-ralph.sh` for `plans_path` and `plan_path` with `require_file_with_hint`, preserving the existing two-line error output. Replace the inline checks in `afk-ralph.sh` for `CONFIG_PATH`, `PLAN_PATH`, `RULES_PATH`, and `SCHEMA_PATH` with `require_file` calls. Ensure the functions use `log_error` and `exit 1` exactly as the current code does.

## Concrete Steps

Work from the repo root.

1. Edit `scripts/lib.sh` to add `require_file` and `require_file_with_hint` helpers that call `log_error` and `exit 1` when the file is missing.
2. Update `run-ralph.sh` to replace the `if [[ ! -f ... ]]` blocks for `plans_path` and `plan_path` with `require_file_with_hint`, keeping the same messages.
3. Update `afk-ralph.sh` to replace the `if [[ ! -f ... ]]` blocks for `CONFIG_PATH`, `PLAN_PATH`, `RULES_PATH`, and `SCHEMA_PATH` with `require_file` calls, keeping the same messages.
4. Run static Bash syntax checks.

## Validation and Acceptance

Acceptance is met when all of the following are true:

- `rg "require_file" -n` shows the helpers defined in `scripts/lib.sh` and used in `run-ralph.sh` and `afk-ralph.sh`.
- `rg "if \[\[ ! -f" -n run-ralph.sh afk-ralph.sh` shows no remaining inline file-existence checks.
- `bash -n run-ralph.sh afk-ralph.sh scripts/lib.sh` completes with exit code 0.

Milestone verification workflow:

1. Tests to write: none. This is a shell refactor validated via static checks and output equivalence.
2. Implementation: perform the edits described above.
3. Verification: run the commands listed in the acceptance criteria and confirm output/exit codes.
4. Commit: after verification passes, commit with a message like `Milestone 1: consolidate file checks`.

## Idempotence and Recovery

These edits are safe to apply more than once because they only change helper call sites. If an entrypoint fails after the change, restore its original inline check and re-run the static checks to isolate the issue.

## Artifacts and Notes

    rg "require_file" -n scripts/lib.sh run-ralph.sh afk-ralph.sh
    run-ralph.sh:29:require_file_with_hint "$plans_path" "Missing target rules: $plans_path" "Run ./init-project.sh \"$project_abs\" first."
    run-ralph.sh:30:require_file_with_hint "$plan_path" "Missing target plan: $plan_path" "Run ./init-project.sh \"$project_abs\" first."
    scripts/lib.sh:28:require_file() {
    scripts/lib.sh:37:require_file_with_hint() {
    afk-ralph.sh:31:  require_file "$CONFIG_PATH" "Missing config: $CONFIG_PATH"
    afk-ralph.sh:50:require_file "$PLAN_PATH" "Missing plan: $PLAN_PATH"
    afk-ralph.sh:52:require_file "$RULES_PATH" "Missing rules: $RULES_PATH"
    afk-ralph.sh:54:require_file "$SCHEMA_PATH" "Missing schema: $SCHEMA_PATH"

    bash -n run-ralph.sh afk-ralph.sh scripts/lib.sh

## Interfaces and Dependencies

`scripts/lib.sh` must export `require_file` and `require_file_with_hint`. Both helpers should log errors via `log_error` and exit with status 1 when a file is missing.

Plan update note: Marked progress complete and recorded verification artifacts after consolidating file-existence checks.
