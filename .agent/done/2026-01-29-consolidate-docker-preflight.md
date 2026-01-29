# Consolidate Docker preflight checks across entrypoints

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

Maintained according to: .agent/PLANS.md

## Purpose / Big Picture

Several host entrypoint scripts verify Docker availability before running, but they do so in slightly different ways. This duplicates logic that already lives in `scripts/lib.sh` and increases the chance of drift as error messaging or checks evolve. After this change, all entrypoints will use a single shared helper to validate Docker and Docker Compose, keeping behavior consistent and reducing duplicated checks. A user running `./run-ralph.sh`, `./authenticate-codex.sh`, or `./docker/run.sh` should see the same failures and messages when Docker is missing, and no other behavior should change.

## Progress

- [x] (2026-01-29 04:13Z) Add a shared Docker preflight helper in `scripts/lib.sh` and replace inline checks in entrypoints.
- [x] (2026-01-29 04:13Z) Verify the entrypoints still run and the Docker checks are centralized.

## Surprises & Discoveries

- Observation: Docker checks are duplicated outside of `scripts/lib.sh`.
  Evidence: `run-ralph.sh` performs direct `command -v docker` and `docker compose version` checks instead of using the existing helpers in `scripts/lib.sh`.

## Decision Log

- Decision: Introduce a single helper in `scripts/lib.sh` that runs both Docker checks and use it in all host entrypoints.
  Rationale: This reduces duplication while keeping the existing error messages and behavior intact.
  Date/Author: 2026-01-29 / Codex

## Outcomes & Retrospective

Docker preflight checks are now centralized in `scripts/lib.sh` and all host entrypoints call the shared helper. Static syntax checks pass and the Docker run smoke check still succeeds with unchanged output.

## Context and Orientation

The runner scripts are Bash entrypoints. `scripts/lib.sh` already provides `require_docker` and `require_docker_compose` helpers used by `authenticate-codex.sh` and `docker/run.sh`. `run-ralph.sh` currently performs the same checks inline. The goal is to consolidate these checks so all entrypoints use one shared preflight helper defined in `scripts/lib.sh`.

## Plan of Work

Update `scripts/lib.sh` to add a small wrapper function (for example, `require_docker_env`) that calls both `require_docker` and `require_docker_compose`. Replace the inline checks in `run-ralph.sh` with a call to this helper, and update `authenticate-codex.sh` and `docker/run.sh` to call the new wrapper instead of invoking each check separately. This leaves the underlying checks unchanged while centralizing the call pattern.

## Concrete Steps

Work from the repo root.

1. Edit `scripts/lib.sh` to add a `require_docker_env` helper that calls `require_docker` and `require_docker_compose`.
2. Edit `run-ralph.sh` to remove the inline `command -v docker` and `docker compose version` checks and call `require_docker_env` instead.
3. Edit `authenticate-codex.sh` and `docker/run.sh` to replace the two separate calls with `require_docker_env`.
4. Run a quick static syntax check on the modified scripts.

## Validation and Acceptance

Acceptance is met when all of the following are true:

- `rg "command -v docker" -n` only matches `scripts/lib.sh` (no inline checks remain in entrypoints).
- `rg "require_docker_env" -n` shows the helper defined in `scripts/lib.sh` and used in `run-ralph.sh`, `authenticate-codex.sh`, and `docker/run.sh`.
- `bash -n run-ralph.sh authenticate-codex.sh docker/run.sh scripts/lib.sh` completes with no output and exit code 0.
- Running `./docker/run.sh /bin/true` still prints `[INFO] Running in Docker.` and exits 0.

Milestone verification workflow:

1. Tests to write: none. This is a shell refactor validated by static checks and a short command run.
2. Implementation: perform the edits described above.
3. Verification: run the commands listed in the acceptance criteria and confirm output/exit codes.
4. Commit: after verification passes, commit with a message like `Milestone 1: consolidate Docker preflight`.

## Idempotence and Recovery

The edits are safe to apply repeatedly because they only change function calls. If an entrypoint fails after the change, restore the previous helper call site and rerun the static checks to isolate the error.

## Artifacts and Notes

    rg "command -v docker" -n
    scripts/lib.sh:85:  if ! command -v docker >/dev/null 2>&1; then

    rg "require_docker_env" -n
    run-ralph.sh:20:require_docker_env
    scripts/lib.sh:98:require_docker_env() {
    authenticate-codex.sh:7:require_docker_env
    docker/run.sh:12:require_docker_env

    ./docker/run.sh /bin/true
    [INFO] Running in Docker.

## Interfaces and Dependencies

`scripts/lib.sh` must export a helper named `require_docker_env` that runs `require_docker` followed by `require_docker_compose`. All host entrypoints should call `require_docker_env` before invoking `docker compose`.

Plan update note: Marked progress complete and recorded verification artifacts after implementing the shared Docker preflight helper.
