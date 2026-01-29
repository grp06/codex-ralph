# Consolidate logging helpers across runner scripts

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

Maintained according to: .agent/PLANS.md

## Purpose / Big Picture

The runner uses multiple Bash entrypoints that all print structured log lines. Today, the basic logging helpers are duplicated in multiple files, which increases drift risk and violates the repo’s stated preference for centralized helpers. After this change, all scripts will use a single set of logging helpers defined in `scripts/lib.sh`, while preserving current output and keeping colorized logs for the long-running container loop. A user should still see the same log lines when running `./run-ralph.sh`, `./authenticate-codex.sh`, or `./docker/run.sh`, and colorized `[INFO]/[STEP]/[OK]/[WARN]/[ERR]` output should remain visible for `afk-ralph.sh` when run in a TTY inside Docker.

## Progress

- [x] (2026-01-29 04:09Z) Consolidate logging helpers into `scripts/lib.sh`, remove duplicate definitions, and preserve colored output for `afk-ralph.sh`.
- [x] (2026-01-29 04:09Z) Verify logging helpers are defined in one place and that scripts still execute with expected log output.

## Surprises & Discoveries

- Observation: Logging helpers are duplicated in multiple entrypoints.
  Evidence: `scripts/lib.sh` defines `log_info/log_warn/log_error`, while `docker/codex-setup.sh` and `afk-ralph.sh` define their own versions.

## Decision Log

- Decision: Centralize all logging helpers in `scripts/lib.sh` with an opt-in color mode for the Docker loop.
  Rationale: This removes duplicate helper implementations, aligns with the architecture guidance to centralize helpers, and keeps output stable by making colorization explicitly enabled only for `afk-ralph.sh`.
  Date/Author: 2026-01-29 / Codex
- Decision: Default `RALPH_LOG_COLOR` to 1 in `afk-ralph.sh` but allow override via parameter expansion.
  Rationale: Preserves the existing color behavior while keeping a simple escape hatch for callers that want to disable color output.
  Date/Author: 2026-01-29 / Codex

## Outcomes & Retrospective

Logging helpers are now centralized in `scripts/lib.sh`, and the container loop continues to opt into colored output. Host scripts retain plain log output. The Docker run smoke check and static Bash syntax checks pass. Color output for `afk-ralph.sh` in a TTY was not directly exercised during this run, but the color gate remains intact via `RALPH_LOG_COLOR=1` and TTY detection.

## Context and Orientation

This repo is a Bash-first runner for the Codex “Ralph” loop. The host entrypoints `run-ralph.sh`, `authenticate-codex.sh`, `init-project.sh`, and `docker/run.sh` source `scripts/lib.sh` for shared helpers. The container entrypoint `afk-ralph.sh` runs the Codex loop and currently defines its own colored logging helpers instead of sourcing `scripts/lib.sh`. The Docker setup script `docker/codex-setup.sh` also defines its own basic logging helpers. The goal is to make `scripts/lib.sh` the single source of truth for logging functions while keeping the `afk-ralph.sh` logs colored when in a TTY.

## Plan of Work

Update `scripts/lib.sh` to include color-aware logging helpers that can be enabled via an environment variable (for example, `RALPH_LOG_COLOR=1`) and to add `log_step` and `log_success` functions so `afk-ralph.sh` can rely entirely on the shared helper set. Then remove the inline logging function definitions from `afk-ralph.sh` and `docker/codex-setup.sh`, sourcing `scripts/lib.sh` instead. In `afk-ralph.sh`, set the opt-in color flag before sourcing so the existing colored output remains, and delete the now-redundant color setup logic in that file. Ensure no other scripts change their output by leaving the color flag unset in host scripts.

## Concrete Steps

Work from the repo root.

1. Edit `scripts/lib.sh` to include optional color setup and the full logging helper set used by the repo.
   - Add `log_step` and `log_success` alongside `log_info`, `log_warn`, and `log_error`.
   - Add a small color initialization block that only enables ANSI colors when `RALPH_LOG_COLOR=1` and stdout is a TTY. In all other cases, use empty color strings so output stays unchanged.
2. Edit `afk-ralph.sh` to remove its local logging helper definitions and color initialization.
   - Set `RALPH_LOG_COLOR=1` before sourcing `scripts/lib.sh` so color output remains for the loop.
   - Source `scripts/lib.sh` and rely on its `log_*` functions throughout the file.
3. Edit `docker/codex-setup.sh` to source `scripts/lib.sh` and remove its local logging helper definitions.
4. Re-run quick checks to ensure only one definition of the logging helpers remains and that scripts are syntactically valid.

## Validation and Acceptance

Acceptance is met when all of the following are true:

- `rg "log_info\(" -n` shows a single definition in `scripts/lib.sh` and no duplicate definitions in `afk-ralph.sh` or `docker/codex-setup.sh`.
- `afk-ralph.sh` still produces colored `[INFO]/[STEP]/[OK]/[WARN]/[ERR]` output when run in a TTY inside Docker (colorization enabled via `RALPH_LOG_COLOR=1`).
- `./docker/run.sh /bin/true` prints the expected `[INFO] Running in Docker.` line without ANSI colors, confirming default behavior is unchanged for host scripts.
- `bash -n afk-ralph.sh docker/codex-setup.sh scripts/lib.sh` completes with no output and exit code 0.

Milestone verification workflow:

1. Tests to write: none. This is a shell refactor with behavior validated via direct command output and static syntax checks.
2. Implementation: perform the edits in `scripts/lib.sh`, `afk-ralph.sh`, and `docker/codex-setup.sh` as described above.
3. Verification: run the commands listed in the acceptance criteria. Confirm expected output and zero exit codes.
4. Commit: after verification passes, commit with a message like `Milestone 1: consolidate logging helpers`.

## Idempotence and Recovery

These edits are safe to apply more than once because they only change function definitions and sourcing. If a script fails after the change, revert the last edit in that script and re-run the syntax checks to isolate the failure.

## Artifacts and Notes

    rg "log_info\\(" -n
    scripts/lib.sh:22:log_info() { printf "%b[INFO]%b %s\n" "$C_BLUE" "$C_RESET" "$*"; }

    ./docker/run.sh /bin/true
    [INFO] Running in Docker.

## Interfaces and Dependencies

The shared logging interface in `scripts/lib.sh` must define the following functions, each accepting a free-form message string:

- `log_info`
- `log_warn`
- `log_error` (writes to stderr)
- `log_step`
- `log_success`

Color output must be controlled by `RALPH_LOG_COLOR=1` and only apply when stdout is a TTY. All scripts should source `scripts/lib.sh` to access these functions, and no other file should define its own `log_*` helpers.
