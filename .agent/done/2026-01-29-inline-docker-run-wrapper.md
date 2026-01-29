# Remove docker/run.sh by inlining Docker launch into afk-ralph.sh

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

Maintained according to: .agent/PLANS.md

## Purpose / Big Picture

The repo currently has a thin wrapper script `docker/run.sh` whose only job is to run `docker compose run --rm` with a couple of flags and call `afk-ralph.sh` inside the container. This duplicates logic already available in `scripts/lib.sh` and introduces an extra file and indirection for a single call site. After this change, `afk-ralph.sh` will invoke Docker directly using the shared helpers, and `docker/run.sh` will be removed. Users should see the same behavior when running `./afk-ralph.sh` from the host: it should still run the container with `RALPH_IN_DOCKER=1` and produce the same log line “Running in Docker.”

## Progress

- [x] (2026-01-29 04:29Z) Inline the Docker launch logic into `afk-ralph.sh` and remove `docker/run.sh`.
- [x] (2026-01-29 04:29Z) Verify static checks and confirm the new Docker launch path uses shared helpers.

## Surprises & Discoveries

- Observation: `docker/run.sh` is a thin wrapper used only by `afk-ralph.sh`.
  Evidence: `rg "docker/run.sh" -n` matches only `afk-ralph.sh` and `docker/run.sh` itself.

## Decision Log

- Decision: Remove `docker/run.sh` and inline its behavior into `afk-ralph.sh` using `docker_compose_run_checked`.
  Rationale: This reduces surface area by eliminating a single-use wrapper and keeps Docker behavior centralized in `scripts/lib.sh`.
  Date/Author: 2026-01-29 / Codex

## Outcomes & Retrospective

`docker/run.sh` has been removed and `afk-ralph.sh` now launches Docker directly via `docker_compose_run_checked`. Static Bash checks pass and no references to the removed wrapper remain.

## Context and Orientation

`afk-ralph.sh` runs the Codex loop inside the Docker container. When run on the host (no `RALPH_IN_DOCKER`), it currently shells out to `./docker/run.sh` which sets `RALPH_IN_DOCKER=1` and executes Docker. The helper functions `require_docker_env`, `docker_compose_run`, and `docker_compose_run_checked` live in `scripts/lib.sh` and already encapsulate preflight checks and the `docker compose run --rm` invocation. The goal is to use those helpers directly from `afk-ralph.sh` and delete the redundant wrapper file.

## Plan of Work

Update `afk-ralph.sh` so that, when not in Docker, it sources `scripts/lib.sh`, logs “Running in Docker.”, and calls `docker_compose_run_checked -e RALPH_IN_DOCKER=1 ralph ./afk-ralph.sh "$@"`. Then remove `docker/run.sh` from the repo. Update any references to `docker/run.sh` (none beyond `afk-ralph.sh` should remain). Ensure static Bash checks pass and that the new call site uses the shared helper functions.

## Concrete Steps

Work from the repo root.

1. Edit `afk-ralph.sh` to replace the `./docker/run.sh` call with:
   - `source "$SCRIPT_DIR/scripts/lib.sh"`
   - `log_info "Running in Docker."`
   - `docker_compose_run_checked -e RALPH_IN_DOCKER=1 ralph ./afk-ralph.sh "$@"`
   - `exit $?`
2. Delete `docker/run.sh`.
3. Run static Bash syntax checks.
4. Confirm no references to `docker/run.sh` remain.

## Validation and Acceptance

Acceptance is met when all of the following are true:

- `rg "docker/run.sh" -n` returns no matches.
- `rg "docker_compose_run_checked" -n afk-ralph.sh` shows the new call site.
- `bash -n afk-ralph.sh scripts/lib.sh` completes with exit code 0.

Milestone verification workflow:

1. Tests to write: none. This is a shell refactor validated via static checks.
2. Implementation: perform the edits described above.
3. Verification: run the commands listed in the acceptance criteria and confirm output/exit codes.
4. Commit: after verification passes, commit with a message like `Milestone 1: inline docker run wrapper`.

## Idempotence and Recovery

These edits are safe to apply more than once. If the Docker launch path breaks, restore the previous `./docker/run.sh` call and re-run the static checks to isolate the error.

## Artifacts and Notes

    rg "docker/run.sh" -n
    (no matches)

    rg "docker_compose_run_checked" -n afk-ralph.sh
    9:  docker_compose_run_checked -e RALPH_IN_DOCKER=1 ralph ./afk-ralph.sh "$@"

    bash -n afk-ralph.sh scripts/lib.sh

## Interfaces and Dependencies

`afk-ralph.sh` must use the shared helper `docker_compose_run_checked` from `scripts/lib.sh` when running on the host, and `docker/run.sh` must be removed from the repo.

Plan update note: Marked progress complete and recorded verification artifacts after inlining the Docker launch path and removing the wrapper.
