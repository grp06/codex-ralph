# Remove docker_compose_run thin wrapper

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

Maintained according to: .agent/PLANS.md

## Purpose / Big Picture

The helper `docker_compose_run` in `scripts/lib.sh` is a thin wrapper that is only used by `docker_compose_run_checked`. This adds an unnecessary abstraction and an extra helper to learn without adding behavior. After this change, `docker_compose_run_checked` will call `docker compose run --rm` directly and the unused wrapper will be removed. Host entrypoints should behave exactly the same as before.

## Progress

- [x] (2026-01-29 04:58Z) Inline `docker_compose_run` into `docker_compose_run_checked` and remove the wrapper.
- [x] (2026-01-29 04:58Z) Update documentation references and verify static Bash checks.

## Surprises & Discoveries

- Observation: `docker_compose_run` is only called by `docker_compose_run_checked`.
  Evidence: `rg "docker_compose_run" -n` shows the helper definition and a single call in `scripts/lib.sh`.

## Decision Log

- Decision: Remove `docker_compose_run` and inline its behavior into `docker_compose_run_checked`.
  Rationale: Eliminates a thin wrapper and reduces surface area without changing behavior.
  Date/Author: 2026-01-29 / Codex

## Outcomes & Retrospective

`docker_compose_run` has been removed and `docker_compose_run_checked` now calls `docker compose run --rm` directly. Documentation was updated and static Bash checks pass.

## Context and Orientation

`scripts/lib.sh` provides Docker helpers: `require_docker_env`, `docker_compose_checked`, and `docker_compose_run_checked`. The wrapper `docker_compose_run` currently exists only to wrap `docker compose run --rm` and is invoked solely by `docker_compose_run_checked`. The goal is to collapse this wrapper to keep the helper set minimal while preserving the same Docker invocation.

## Plan of Work

Update `docker_compose_run_checked` to call `docker compose run --rm` directly, then remove `docker_compose_run`. Update `ARCHITECTURE.md` to remove references to the deleted helper. Verify with static Bash checks.

## Concrete Steps

Work from the repo root.

1. Edit `scripts/lib.sh` to remove `docker_compose_run` and inline `docker compose run --rm` into `docker_compose_run_checked`.
2. Update `ARCHITECTURE.md` to remove `docker_compose_run` from the list of Docker helpers and any related design notes.
3. Run static Bash syntax checks.

## Validation and Acceptance

Acceptance is met when all of the following are true:

- `rg "docker_compose_run" -n scripts/lib.sh` shows no matches.
- `rg "docker_compose_run_checked" -n scripts/lib.sh` shows the helper still defined and calling `docker compose run --rm` directly.
- `bash -n scripts/lib.sh` completes with exit code 0.

Milestone verification workflow:

1. Tests to write: none. This is a shell refactor validated via static checks.
2. Implementation: perform the edits described above.
3. Verification: run the commands listed in the acceptance criteria and confirm output/exit codes.
4. Commit: after verification passes, commit with a message like `Milestone 1: remove docker_compose_run wrapper`.

## Idempotence and Recovery

These edits are safe to apply more than once because they only remove a thin wrapper. If behavior changes unexpectedly, reintroduce `docker_compose_run` with its previous implementation and re-run the static checks to isolate the issue.

## Artifacts and Notes

    rg "docker_compose_run" -n scripts/lib.sh
    129:docker_compose_run_checked() {

    bash -n scripts/lib.sh

## Interfaces and Dependencies

`scripts/lib.sh` must expose `docker_compose_run_checked` and `docker_compose_checked` only; `docker_compose_run` should no longer exist.

Plan update note: Marked progress complete and recorded verification artifacts after removing the docker_compose_run wrapper.
