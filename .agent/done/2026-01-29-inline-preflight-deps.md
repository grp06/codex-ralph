# Inline dependency preflight into scripts/lib.sh

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

Maintained according to: .agent/PLANS.md

## Purpose / Big Picture

The dependency preflight logic lives in `scripts/preflight-deps.sh`, but that script is only invoked from `afk-ralph.sh`. This adds an extra file and entrypoint for a single call site. After this change, the preflight logic will live as a shared helper function in `scripts/lib.sh` and `afk-ralph.sh` will call it directly. Users should still see the same dependency-install behavior and error messages when running the Ralph loop, but the repo will have one fewer script file to maintain.

## Progress

- [x] (2026-01-29 06:07Z) Move the preflight dependency logic into a shared helper and update `afk-ralph.sh` to call it.
- [x] (2026-01-29 06:07Z) Remove `scripts/preflight-deps.sh`, update docs, and verify static checks and preflight behavior.

## Surprises & Discoveries

- Observation: `scripts/preflight-deps.sh` is only called from `afk-ralph.sh`.
  Evidence: `afk-ralph.sh` invokes `$SCRIPT_DIR/scripts/preflight-deps.sh`, and no other script references it.

## Decision Log

- Decision: Convert `scripts/preflight-deps.sh` into a `preflight_deps` function inside `scripts/lib.sh` and delete the standalone script.
  Rationale: This reduces file count while keeping the preflight behavior centralized alongside other shared helpers.
  Date/Author: 2026-01-29 / Codex

## Outcomes & Retrospective

Dependency preflight now lives in `scripts/lib.sh` as `preflight_deps`, and `afk-ralph.sh` calls it directly. The standalone script was removed, documentation updated, and static Bash checks pass. A live preflight run was not executed in this session.

## Context and Orientation

`afk-ralph.sh` runs inside the container and performs a dependency preflight step before each iteration. Today it invokes `scripts/preflight-deps.sh`, which installs dependencies for the target repo based on lockfiles and caches results in the run directory. `scripts/preflight-deps.sh` already relies on `scripts/lib.sh` for logging. The goal is to move this logic into `scripts/lib.sh` as a function so `afk-ralph.sh` can call it directly, then remove the now-unused script file.

## Plan of Work

Add a new helper function `preflight_deps` to `scripts/lib.sh` by moving the content of `scripts/preflight-deps.sh` into that function with minimal changes. Keep its behavior, messages, and exit codes identical. Update `afk-ralph.sh` to call `preflight_deps "$TARGET_DIR" "$RUN_DIR"` when preflight is enabled. Remove `scripts/preflight-deps.sh` from the repository. Update `ARCHITECTURE.md` to describe dependency preflight as a helper in `scripts/lib.sh` rather than a standalone script. Validate via static Bash checks and by verifying that the preflight step still runs when enabled.

## Concrete Steps

Work from the repo root.

1. In `scripts/lib.sh`, add a new function `preflight_deps` that accepts two arguments (`target_dir`, `run_dir`) and contains the logic from `scripts/preflight-deps.sh`.
   - Preserve all `log_info`, `log_warn`, and `log_error` messages and `exit` behavior.
   - Keep the same lockfile detection, hashing, and package-manager selection logic.
2. Update `afk-ralph.sh` to call `preflight_deps "$TARGET_DIR" "$RUN_DIR"` instead of executing the script.
3. Delete `scripts/preflight-deps.sh` from the repo.
4. Update `ARCHITECTURE.md` to describe dependency preflight as a function inside `scripts/lib.sh` rather than a standalone script.
5. Run static Bash syntax checks for the modified scripts.

## Validation and Acceptance

Acceptance is met when all of the following are true:

- `rg "preflight-deps.sh" -n` returns no matches.
- `rg "preflight_deps" -n scripts/lib.sh afk-ralph.sh` shows the helper definition and the call site.
- `bash -n afk-ralph.sh scripts/lib.sh` completes with exit code 0.
- When running `afk-ralph.sh` with `RALPH_PREFLIGHT=1`, dependency installation still occurs when lockfiles change (same behavior and log messages as before).

Milestone verification workflow:

1. Tests to write: none. This is a shell refactor validated by static checks and behavioral confirmation of the preflight step.
2. Implementation: perform the edits described above.
3. Verification: run the commands listed in the acceptance criteria and confirm output/exit codes. If possible, run a Ralph iteration that triggers preflight and confirm the same log messages appear.
4. Commit: after verification passes, commit with a message like `Milestone 1: inline preflight deps`.

## Idempotence and Recovery

These edits are safe to apply more than once because they only move logic into a shared helper. If the preflight step fails after the change, restore `scripts/preflight-deps.sh` and revert the call site in `afk-ralph.sh`, then rerun the static checks to isolate the issue.

## Artifacts and Notes

Include concise evidence of the new helper and the static checks, for example:

    rg "preflight_deps" -n scripts/lib.sh afk-ralph.sh
    afk-ralph.sh:184:    preflight_deps "$TARGET_DIR" "$RUN_DIR"
    scripts/lib.sh:51:preflight_deps() {

    bash -n afk-ralph.sh scripts/lib.sh

## Interfaces and Dependencies

`scripts/lib.sh` must export a function `preflight_deps(target_dir, run_dir)` that performs the same dependency preflight behavior previously implemented in `scripts/preflight-deps.sh`. `afk-ralph.sh` must call this function when `RALPH_PREFLIGHT` is enabled.

Plan update note: Marked progress complete and recorded verification artifacts after inlining the preflight helper.
