# Consolidate Docker preflight + run invocation

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

Maintained according to: .agent/PLANS.md

## Purpose / Big Picture

Host entrypoints currently perform Docker preflight checks (`require_docker_env`) and then call `docker_compose_run` as two separate steps. This sequence is repeated across multiple scripts. After this change, a single helper in `scripts/lib.sh` will perform the preflight and invoke `docker compose run --rm` in one step. This reduces duplicated call patterns while keeping error messages and Docker invocation behavior consistent. Users should see the same success output and the same Docker-related error messages when Docker is missing.

## Progress

- [x] (2026-01-29 04:24Z) Add a shared helper that combines Docker preflight and `docker_compose_run`, and update entrypoints to use it.
- [x] (2026-01-29 04:24Z) Verify entrypoints still execute and that preflight is centralized.

## Surprises & Discoveries

- Observation: Docker preflight and Docker run are separate calls repeated across entrypoints.
  Evidence: `authenticate-codex.sh` and `docker/run.sh` call `require_docker_env` followed by `docker_compose_run`; `run-ralph.sh` follows the same pattern.

## Decision Log

- Decision: Add a `docker_compose_run_checked` helper that runs `require_docker_env` and then `docker_compose_run`.
  Rationale: This consolidates the repeated two-step pattern without changing the underlying error messages or Docker invocation flags.
  Date/Author: 2026-01-29 / Codex
- Decision: Add `docker_compose_checked` for non-run Docker Compose commands that still need preflight.
  Rationale: `authenticate-codex.sh` calls `docker compose build`; moving preflight into a helper keeps entrypoints free of `require_docker_env` while preserving the existing error messages.
  Date/Author: 2026-01-29 / Codex

## Outcomes & Retrospective

Docker preflight + run is now centralized in `docker_compose_run_checked`, and the only remaining preflight call sites live in `scripts/lib.sh`. `authenticate-codex.sh` now uses `docker_compose_checked` for the build step. Static Bash checks and a Docker run smoke test pass with unchanged output.

## Context and Orientation

This repo’s host entrypoints use Docker to run the `ralph` service defined in `docker-compose.yml`. `scripts/lib.sh` currently exposes `require_docker_env` (preflight checks) and `docker_compose_run` (executes `docker compose run --rm`). The entrypoints call both helpers in sequence. The goal is to centralize that sequence into a single helper to reduce duplication.

## Plan of Work

Add a new helper in `scripts/lib.sh` (named `docker_compose_run_checked`) that calls `require_docker_env` and then `docker_compose_run` with all arguments. Add a second helper `docker_compose_checked` for non-run subcommands that still need preflight. Update `run-ralph.sh`, `authenticate-codex.sh`, and `docker/run.sh` to replace the two-call sequence with the new helper and to use `docker_compose_checked build` in `authenticate-codex.sh`. Keep all arguments and environment variables unchanged.

## Concrete Steps

Work from the repo root.

1. Edit `scripts/lib.sh` to add `docker_compose_run_checked` (preflight + run) and `docker_compose_checked` (preflight + `docker compose "$@"`).
2. Edit `run-ralph.sh` to replace the standalone `require_docker_env` call and the `docker_compose_run` invocation with `docker_compose_run_checked`, keeping the argument list unchanged.
3. Edit `authenticate-codex.sh` to use `docker_compose_checked build` and `docker_compose_run_checked` for the setup run. Update `docker/run.sh` to replace its `require_docker_env` + `docker_compose_run` sequence with `docker_compose_run_checked`.
4. Run static Bash syntax checks and a Docker smoke test.

## Validation and Acceptance

Acceptance is met when all of the following are true:

- `rg "require_docker_env" -n` shows the helper only in `scripts/lib.sh` (no entrypoints reference it directly).
- `rg "docker_compose_run_checked" -n` shows the helper defined in `scripts/lib.sh` and used in `run-ralph.sh`, `authenticate-codex.sh`, and `docker/run.sh`.
- `rg "docker_compose_checked" -n` shows the helper defined in `scripts/lib.sh` and used in `authenticate-codex.sh`.
- `bash -n run-ralph.sh authenticate-codex.sh docker/run.sh scripts/lib.sh` completes with exit code 0.
- `./docker/run.sh /bin/true` prints `[INFO] Running in Docker.` and exits 0.

Milestone verification workflow:

1. Tests to write: none. This is a shell refactor validated via static checks and a simple command run.
2. Implementation: perform the edits described above.
3. Verification: run the commands listed in the acceptance criteria and confirm outputs/exit codes.
4. Commit: after verification passes, commit with a message like `Milestone 1: consolidate docker preflight + run`.

## Idempotence and Recovery

These edits are safe to apply more than once because they only change helper call sites. If an entrypoint fails, restore the original call pattern in that script and re-run the static checks to isolate the issue.

## Artifacts and Notes

    rg "docker_compose_run_checked" -n
    scripts/lib.sh:121:docker_compose_run_checked() {
    run-ralph.sh:46:docker_compose_run_checked \
    authenticate-codex.sh:11:docker_compose_run_checked ralph /workspace/docker/codex-setup.sh
    docker/run.sh:13:docker_compose_run_checked -e RALPH_IN_DOCKER=1 ralph "$@"

    rg "docker_compose_checked" -n
    scripts/lib.sh:116:docker_compose_checked() {
    authenticate-codex.sh:8:docker_compose_checked build

    ./docker/run.sh /bin/true
    [INFO] Running in Docker.

## Interfaces and Dependencies

`scripts/lib.sh` must export `docker_compose_run_checked`, which runs `require_docker_env` followed by `docker_compose_run` with the provided arguments, and `docker_compose_checked`, which runs `require_docker_env` followed by `docker compose "$@"`. All host entrypoints should call `docker_compose_run_checked` instead of invoking both helpers separately; `authenticate-codex.sh` should call `docker_compose_checked build` for the build step.

Plan update note: Marked progress complete and recorded verification artifacts after consolidating Docker preflight + run, adding a checked helper for Docker Compose build.
