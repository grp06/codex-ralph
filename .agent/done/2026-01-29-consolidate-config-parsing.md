# Consolidate model_reasoning_effort parsing via shared config helper

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

Maintained according to: .agent/PLANS.md

## Purpose / Big Picture

`afk-ralph.sh` currently parses `model_reasoning_effort` from `ralph.config.toml` using a custom `awk` pipeline, while the repo already has a shared `read_config_value` helper in `scripts/lib.sh` for config parsing. This duplication is easy to drift and makes configuration behavior inconsistent. After this change, `afk-ralph.sh` will use the shared helper, keeping config parsing centralized and consistent. Users should see the same runtime behavior and error messages when `model_reasoning_effort` is missing or invalid.

## Progress

- [x] (2026-01-29 04:48Z) Replace the custom `awk` parsing in `afk-ralph.sh` with `read_config_value`.
- [x] (2026-01-29 04:48Z) Verify the new parsing path and static Bash checks.

## Surprises & Discoveries

- Observation: `afk-ralph.sh` reimplements config parsing despite an existing helper in `scripts/lib.sh`.
  Evidence: `afk-ralph.sh` uses `awk -F=` to parse `model_reasoning_effort`, while `scripts/lib.sh` defines `read_config_value`.

## Decision Log

- Decision: Use `read_config_value` in `afk-ralph.sh` for `model_reasoning_effort` parsing.
  Rationale: Centralizes config parsing and reduces the chance of divergent behavior.
  Date/Author: 2026-01-29 / Codex

## Outcomes & Retrospective

`afk-ralph.sh` now uses `read_config_value` to parse `model_reasoning_effort`. Static Bash checks pass, and the config parsing path is centralized in `scripts/lib.sh`.

## Context and Orientation

`afk-ralph.sh` runs inside the container and reads `ralph.config.toml` (via `$CONFIG_PATH`) to set `REASONING_EFFORT`. The helper `read_config_value` in `scripts/lib.sh` already handles key lookup and trimming in `ralph.config.toml`. The goal is to reuse that helper instead of a bespoke `awk` pipeline.

## Plan of Work

Update `afk-ralph.sh` to call `read_config_value "model_reasoning_effort" "$CONFIG_PATH"` and apply the same fallback logic that exists today (default to `medium` when missing). Remove the custom `awk` parsing. No other behavior should change, including validation of allowed values.

## Concrete Steps

Work from the repo root.

1. Edit `afk-ralph.sh` to replace the `awk` pipeline with a call to `read_config_value`.
2. Keep the existing default behavior: when the value is missing or empty, leave `REASONING_EFFORT` as `medium`.
3. Run static Bash syntax checks.

## Validation and Acceptance

Acceptance is met when all of the following are true:

- `rg "model_reasoning_effort" -n afk-ralph.sh` shows the new `read_config_value` usage and no `awk -F=` parsing for this key.
- `bash -n afk-ralph.sh scripts/lib.sh` completes with exit code 0.

Milestone verification workflow:

1. Tests to write: none. This is a shell refactor validated via static checks.
2. Implementation: perform the edits described above.
3. Verification: run the commands listed in the acceptance criteria and confirm output/exit codes.
4. Commit: after verification passes, commit with a message like `Milestone 1: consolidate config parsing`.

## Idempotence and Recovery

These edits are safe to apply more than once because they only change the parsing method. If behavior changes unexpectedly, restore the previous `awk` parsing and re-run the static checks to isolate the issue.

## Artifacts and Notes

    rg "model_reasoning_effort" -n afk-ralph.sh
    37:  parsed_effort="$(read_config_value "model_reasoning_effort" "$CONFIG_PATH")"
    46:    log_error "Invalid model_reasoning_effort: $REASONING_EFFORT (expected minimal|low|medium|high|xhigh)"
    210:    -c "model_reasoning_effort=\"$REASONING_EFFORT\""

    bash -n afk-ralph.sh scripts/lib.sh

## Interfaces and Dependencies

`afk-ralph.sh` must use `read_config_value` from `scripts/lib.sh` to read `model_reasoning_effort` from `$CONFIG_PATH`.

Plan update note: Marked progress complete and recorded verification artifacts after consolidating config parsing.
