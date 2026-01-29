# Consolidate target repo resolution and validation in host scripts

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

Maintained according to: .agent/PLANS.md

## Purpose / Big Picture

Reduce duplicated host-side bootstrapping logic by centralizing target repo resolution and validation. After this change, both `run-ralph.sh` and `init-project.sh` will resolve the target repo path in exactly one place, with the same error messages and validation, making future changes safer and simpler while preserving current behavior.

## Progress

- [x] (2026-01-29 03:56Z) Review `run-ralph.sh` and `init-project.sh` and define the shared helper signature for resolving and validating the target repo.
- [x] (2026-01-29 03:56Z) Implement the helper in `scripts/lib.sh` and update `run-ralph.sh` and `init-project.sh` to use it.
- [x] (2026-01-29 03:56Z) Verify shell syntax and behavior with targeted command runs; record results and commit.

## Surprises & Discoveries

None yet.

## Decision Log

- Decision: Centralize target repo resolution and validation in `scripts/lib.sh` instead of duplicating logic in host entry scripts.
  Rationale: Two entrypoints use nearly identical logic; centralizing reduces cognitive load and avoids drift without expanding scope.
  Date/Author: 2026-01-29 / Codex

## Outcomes & Retrospective

Completed consolidation of target repo resolution into `scripts/lib.sh` and updated host scripts to use it, preserving current error behavior while reducing duplication.

## Context and Orientation

The host entrypoints `run-ralph.sh` and `init-project.sh` both accept an optional target repo path argument or read `target_repo_path` from `ralph.config.toml`. Each script then expands `~`, checks that the path exists, and verifies it is a git repo by asserting the presence of `.git`. This logic is duplicated in both scripts. Shared helpers live in `scripts/lib.sh`, which already provides `read_config_value`, `expand_path`, and logging helpers. The change will add a new helper in `scripts/lib.sh` that encapsulates the shared resolution and validation steps and then use it in both host entry scripts.

Key files:
- `scripts/lib.sh`: shared helper functions.
- `run-ralph.sh`: host entrypoint that starts the loop in Docker.
- `init-project.sh`: host entrypoint that seeds a target repo with plan files.
- `ralph.config.toml`: optional source of `target_repo_path`.

## Plan of Work

Add a new helper function in `scripts/lib.sh` that accepts three inputs: an optional argument path, the config path, and an optional usage function name. It should read `target_repo_path` from the config file when no argument is supplied, expand `~`, then validate that the resulting path exists and is a git repo. If the path is missing, it should print usage when provided, emit the same error message currently used, and exit with a non-zero status. Then replace the duplicated blocks in `run-ralph.sh` and `init-project.sh` with calls to this helper, preserving current behavior and error strings. Keep `usage()` in each script so the helper can invoke it when needed.

## Concrete Steps

1. From the repo root `/Users/georgepickett/ralph-new`, edit `scripts/lib.sh` to add a helper such as `resolve_target_repo` that performs: read-config-if-missing, expand, path existence check, and `.git` check, then prints the resolved path to stdout.
2. Update `run-ralph.sh` to call the helper using the first CLI argument (if any) and shift only when an argument was supplied. Keep the current usage message and error text unchanged.
3. Update `init-project.sh` to call the helper using the first CLI argument (if any). Keep the current usage message and error text unchanged.
4. Run shell syntax checks:
   - `bash -n scripts/lib.sh run-ralph.sh init-project.sh`
5. Run behavior checks without requiring Docker:
   - `./run-ralph.sh /does/not/exist` should print `Project path does not exist: /does/not/exist` and exit non-zero before any Docker invocation.
   - `tmp_repo="$(mktemp -d)"; (cd "$tmp_repo" && git init -q); ./init-project.sh "$tmp_repo"` should create `.agent/PLANS.md` and `.agent/execplans/execplan.md` inside the temp repo and exit successfully.

## Validation and Acceptance

Acceptance criteria:
- `run-ralph.sh` and `init-project.sh` both resolve the target repo path through a single shared helper in `scripts/lib.sh`.
- Error messages for missing path, non-existent path, and non-git repo remain identical to current behavior.
- `bash -n scripts/lib.sh run-ralph.sh init-project.sh` succeeds.
- The two command checks in the Concrete Steps behave as described.

Verification workflow for this milestone:
1. Tests to write: No automated test framework exists in this repo; use the command checks in the Concrete Steps as verification.
2. Implementation: Add the helper in `scripts/lib.sh` and replace the duplicated blocks in `run-ralph.sh` and `init-project.sh` with calls to it.
3. Verification: Run the syntax checks and behavior commands; confirm outputs match the acceptance criteria.
4. Commit: After verification passes, commit with a message like `Milestone 1: consolidate target repo resolution`.

## Idempotence and Recovery

These steps are safe to repeat; re-running the scripts should not corrupt state. The temporary repo created with `mktemp -d` can be left in place to avoid directory deletion. If a change needs to be reverted, use git to reset the modified files back to the prior commit.

## Artifacts and Notes

Syntax check:

    bash -n scripts/lib.sh run-ralph.sh init-project.sh
    (no output; exit 0)

`init-project.sh` success output:

    [INFO] Created /var/folders/8g/plw_4x_1249db2_cylgcxrw00000gn/T/tmp.E1LwyM4aVX/.agent/PLANS.md
    [INFO] Created /var/folders/8g/plw_4x_1249db2_cylgcxrw00000gn/T/tmp.E1LwyM4aVX/.agent/execplans/execplan.md
    [INFO] Edit the ExecPlan, then run ./run-ralph.sh "/var/folders/8g/plw_4x_1249db2_cylgcxrw00000gn/T/tmp.E1LwyM4aVX"

## Interfaces and Dependencies

In `scripts/lib.sh`, define a helper with a stable signature such as:

    resolve_target_repo <arg_path> <config_path> <usage_fn>

Expected behavior:
- If `arg_path` is empty, read `target_repo_path` from `config_path` using `read_config_value` and expand `~` using `expand_path`.
- If the resolved path is empty, call `<usage_fn>` when provided, log the existing missing-path error message, and exit non-zero.
- If the path does not exist or lacks a `.git` directory, log the existing error messages and exit non-zero.
- Otherwise, print the resolved path to stdout.

`run-ralph.sh` and `init-project.sh` should call this helper and rely on the returned path rather than duplicating the validation logic.

Plan update note: Marked progress complete, recorded verification artifacts, and summarized outcomes after implementing the refactor.
