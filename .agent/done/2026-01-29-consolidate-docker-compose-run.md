# Consolidate Docker compose run invocation

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

Maintained according to: .agent/PLANS.md

## Purpose / Big Picture

Multiple entrypoint scripts invoke `docker compose run --rm` directly, repeating the same base command and service name. This duplicates the core invocation pattern and makes future changes (like adding a shared flag) harder to roll out consistently. After this change, all entrypoints will use a single helper in `scripts/lib.sh` to run `docker compose run --rm`, keeping behavior consistent while reducing surface area. A user running `./run-ralph.sh`, `./authenticate-codex.sh`, or `./docker/run.sh` should see the same behavior and output as before.

## Progress

- [x] (2026-01-29 04:16Z) Add a shared `docker_compose_run` helper to `scripts/lib.sh` and replace direct invocations in entrypoints.
- [x] (2026-01-29 04:16Z) Verify the entrypoints still execute and the direct `docker compose run` calls are removed.

## Surprises & Discoveries

- Observation: Three entrypoints call `docker compose run --rm` directly.
  Evidence: `rg "docker compose run" -n` matches `run-ralph.sh`, `authenticate-codex.sh`, and `docker/run.sh`.

## Decision Log

- Decision: Centralize `docker compose run --rm` in a helper named `docker_compose_run`.
  Rationale: This reduces duplication while keeping call sites explicit about their flags and arguments.
  Date/Author: 2026-01-29 / Codex

## Outcomes & Retrospective

The Docker compose run invocation is centralized in `scripts/lib.sh` and all entrypoints now call the shared helper. Static Bash checks and a Docker run smoke test pass with unchanged output.

## Context and Orientation

This repo is a Bash-first runner for Codex “Ralph.” Host entrypoints use Docker to run the `ralph` service defined in `docker-compose.yml`. `run-ralph.sh`, `authenticate-codex.sh`, and `docker/run.sh` each call `docker compose run --rm` with different flags and arguments. `scripts/lib.sh` already centralizes common helpers used by these entrypoints and is the appropriate place to consolidate the base Docker run invocation.

## Plan of Work

Add a `docker_compose_run` helper to `scripts/lib.sh` that wraps `docker compose run --rm` and forwards all arguments. Update `run-ralph.sh`, `authenticate-codex.sh`, and `docker/run.sh` to call the helper instead of invoking `docker compose run` directly. Keep the argument lists and environment variables unchanged so runtime behavior is identical.

## Concrete Steps

Work from the repo root.

1. Edit `scripts/lib.sh` to add a `docker_compose_run` function that runs `docker compose run --rm "$@"`.
2. Edit `run-ralph.sh` to replace the direct `docker compose run --rm` call with `docker_compose_run`, preserving all existing flags and arguments.
3. Edit `authenticate-codex.sh` and `docker/run.sh` to replace their direct `docker compose run --rm` calls with `docker_compose_run`.
4. Run static Bash syntax checks and a small Docker smoke test.

## Validation and Acceptance

Acceptance is met when all of the following are true:

- `rg "docker compose run" -n` shows no matches in `run-ralph.sh`, `authenticate-codex.sh`, or `docker/run.sh`.
- `rg "docker_compose_run" -n` shows the helper defined in `scripts/lib.sh` and used in all three entrypoints.
- `bash -n run-ralph.sh authenticate-codex.sh docker/run.sh scripts/lib.sh` completes with exit code 0.
- `./docker/run.sh /bin/true` prints `[INFO] Running in Docker.` and exits 0.

Milestone verification workflow:

1. Tests to write: none. This is a shell refactor validated via static checks and a simple command run.
2. Implementation: perform the edits described above.
3. Verification: run the commands listed in the acceptance criteria and confirm outputs/exit codes.
4. Commit: after verification passes, commit with a message like `Milestone 1: consolidate docker compose run`.

## Idempotence and Recovery

These edits are safe to apply more than once because they only change helper call sites. If any script fails, revert that script’s helper call and re-run the syntax checks to isolate the error.

## Artifacts and Notes

    rg "docker compose run" -n
    scripts/lib.sh:104:  docker compose run --rm "$@"

    rg "docker_compose_run" -n
    run-ralph.sh:48:docker_compose_run \
    scripts/lib.sh:103:docker_compose_run() {
    authenticate-codex.sh:13:docker_compose_run ralph /workspace/docker/codex-setup.sh
    docker/run.sh:15:docker_compose_run -e RALPH_IN_DOCKER=1 ralph "$@"

    ./docker/run.sh /bin/true
    [INFO] Running in Docker.

## Interfaces and Dependencies

`scripts/lib.sh` must export a `docker_compose_run` function that runs `docker compose run --rm` with all passed arguments. All host entrypoints should use this helper instead of directly calling `docker compose run`.

Plan update note: Marked progress complete and captured verification artifacts after implementing the shared docker compose helper.
