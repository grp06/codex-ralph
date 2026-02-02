# Make afk-ralph container-only and remove the duplicate host entrypoint

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

Maintained according to: .agent/PLANS.md

## Purpose / Big Picture

Today there are two ways to start the container loop: the intended host entrypoint `run-ralph.sh`, and a hidden fallback inside `afk-ralph.sh` that re-invokes Docker when `RALPH_IN_DOCKER` is missing. This fallback is undocumented and does not pass the full set of environment variables that `run-ralph.sh` sets, which makes behavior easy to misconfigure. After this change, there is exactly one host entrypoint. Running `./run-ralph.sh <project-path>` remains the supported way to start Ralph, and running `./afk-ralph.sh` on the host fails fast with a clear error. The visible effect is a simpler mental model and fewer ambiguous code paths, with no change to the container loop itself.

## Progress

- [x] (2026-02-02T22:55Z) Remove the host fallback in `afk-ralph.sh` and add a fail-fast guard that directs users to `run-ralph.sh`.
- [ ] (2026-02-02 00:00Z) Update documentation to describe the single host entrypoint and remove references to the old handoff path.
- [ ] (2026-02-02 00:00Z) Run verification commands and record evidence.

## Surprises & Discoveries

- Observation: None.
  Evidence: Not applicable.

## Decision Log

- Decision: Make `afk-ralph.sh` container-only and eliminate its host-mode fallback.
  Rationale: It removes an undocumented, partially configured execution path and leaves a single, consistent host entrypoint (`run-ralph.sh`).
  Date/Author: 2026-02-02 / Codex

## Outcomes & Retrospective

- Outcome: `afk-ralph.sh` now fails fast on the host and only runs inside the container.
- What remains: Update documentation and record verification evidence.
- Lessons: Not yet captured.

## Context and Orientation

This repo is the Ralph runner itself. The host entrypoint is `run-ralph.sh`, which resolves the target repo, constructs run directories under `runs/`, and launches the container with the full set of `RALPH_*` environment variables. Inside the container, `afk-ralph.sh` runs the loop that calls `codex exec` and updates logs. Shared helpers like `log_info` and `docker_compose_checked` live in `scripts/lib.sh`. `docker-compose.yml` defines the `ralph` service and sets some environment variables for container runs. `ARCHITECTURE.md` documents the host-to-container flow, and currently mentions a host fallback inside `afk-ralph.sh`.

Run Logs: container=/workspace/runs/ralph-new/.ralph/logs; host=/Users/georgepickett/ralph-new/runs/ralph-new/.ralph/logs

## Plan of Work

First, modify `afk-ralph.sh` so it no longer tries to launch Docker on its own. Replace the initial `RALPH_IN_DOCKER` check with a fail-fast guard that prints a clear error and exits when the script is run outside the container. Keep using `scripts/lib.sh` for logging to avoid ad hoc output.

Second, update documentation to match the new single-entrypoint behavior. In `ARCHITECTURE.md`, remove the statement that `afk-ralph.sh` re-enters Docker on the host, and explicitly state that `run-ralph.sh` is the only host entrypoint while `afk-ralph.sh` is container-only.

Third, verify the change using lightweight, local checks that do not require a Codex login. Use shell syntax checks and a host execution check of `afk-ralph.sh` to confirm it fails fast with the new guidance. Record short transcripts in Artifacts and Notes.

## Concrete Steps

1. Edit `afk-ralph.sh` near the top of the file where the `RALPH_IN_DOCKER` guard currently exists. Replace the Docker re-entry branch with a guard that logs an error and exits with a non-zero status when `RALPH_IN_DOCKER` is missing.
2. Edit `ARCHITECTURE.md` in the “Data Flow and Boundaries” section to remove the host fallback description and to clarify that `run-ralph.sh` is the single host entrypoint.
3. Run the verification commands below from the repo root and capture the outputs.

## Validation and Acceptance

Acceptance is met when:

1) Running `./afk-ralph.sh` on the host exits immediately with a clear error message telling the user to use `./run-ralph.sh <project-path>`.
2) `ARCHITECTURE.md` no longer claims that `afk-ralph.sh` re-enters Docker when run on the host, and instead documents the single host entrypoint.
3) All modified shell scripts pass a syntax check via `bash -n`.

Verification workflow for Milestone 1:

1. Tests to write: None (shell scripts). This repo does not have a test harness for these scripts.
2. Implementation: Update `afk-ralph.sh` to remove the host fallback and add the fail-fast guard using `log_error` and `exit 1`.
3. Verification: From the repo root, run:

   bash -n afk-ralph.sh
   ./afk-ralph.sh

   Confirm the syntax check exits successfully and the script prints the error and exits without invoking Docker.
4. Commit: Commit with message "Milestone 1: Make afk-ralph container-only".

Verification workflow for Milestone 2:

1. Tests to write: None.
2. Implementation: Update `ARCHITECTURE.md` to remove the host fallback note and document `run-ralph.sh` as the single host entrypoint.
3. Verification: Run:

   rg -n "afk-ralph" ARCHITECTURE.md

   Confirm the text matches the new behavior.
4. Commit: Commit with message "Milestone 2: Update architecture docs for single entrypoint".

Verification workflow for Milestone 3:

1. Tests to write: None.
2. Implementation: Capture the verification transcripts in `Artifacts and Notes`.
3. Verification: Ensure the transcripts show the expected error message from `./afk-ralph.sh` and successful `bash -n` output.
4. Commit: Commit with message "Milestone 3: Record verification evidence".

## Idempotence and Recovery

Re-running the edits is safe; the guard in `afk-ralph.sh` will remain a simple check, and documentation edits are text-only. If anything goes wrong, revert the last commit and re-apply the edits. No data or external state is modified.

## Artifacts and Notes

No verification transcripts recorded yet.

## Interfaces and Dependencies

No new dependencies are introduced. Continue using `scripts/lib.sh` logging helpers, especially `log_error`, and keep `run-ralph.sh` as the sole host entrypoint.

Plan Update Note (2026-02-02T22:55Z): Marked milestone 1 complete after adding the container-only guard to `afk-ralph.sh`.
