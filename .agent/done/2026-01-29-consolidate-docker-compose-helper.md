# Consolidate Docker Compose helpers into a single entrypoint

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

Maintained according to: .agent/PLANS.md

## Purpose / Big Picture

The helper set in `scripts/lib.sh` currently includes both `docker_compose_checked` and `docker_compose_run_checked`. They overlap in responsibility (both perform preflight and then run Docker Compose) and add an extra concept for the same workflow. After this change, only a single helper (`docker_compose_checked`) will remain and all call sites will pass their subcommand (e.g., `run --rm`, `build`). This reduces surface area while preserving behavior and error messages.

## Progress

- [x] (2026-01-29 05:27Z) Remove `docker_compose_run_checked` and update entrypoints to use `docker_compose_checked` with explicit subcommands.
- [x] (2026-01-29 05:27Z) Update documentation references and verify static Bash checks.

## Surprises & Discoveries

- Observation: `docker_compose_run_checked` and `docker_compose_checked` both perform preflight and then invoke Docker Compose, differing only by the subcommand.
  Evidence: `scripts/lib.sh` defines both helpers, and `docker_compose_run_checked` is only used to run `docker compose run --rm`.

## Decision Log

- Decision: Remove `docker_compose_run_checked` and use `docker_compose_checked` with explicit subcommands at call sites.
  Rationale: Consolidates Docker Compose invocation into a single helper, reducing helper count without changing behavior.
  Date/Author: 2026-01-29 / Codex

## Outcomes & Retrospective

`docker_compose_run_checked` has been removed and all call sites now use `docker_compose_checked` with explicit subcommands. Documentation was updated and static Bash checks pass.

## Context and Orientation

`scripts/lib.sh` provides Docker helpers. `docker_compose_checked` runs `require_docker_env` then `docker compose "$@"`. `docker_compose_run_checked` currently does the same preflight and then runs `docker compose run --rm`. Entry points (`run-ralph.sh`, `afk-ralph.sh`, `authenticate-codex.sh`) all use the run-specific helper. The goal is to keep only one helper and make the call sites explicit about the subcommand.

## Plan of Work

Delete `docker_compose_run_checked` from `scripts/lib.sh`. Update all call sites to call `docker_compose_checked` with the correct subcommand (`run --rm ...`). Update `ARCHITECTURE.md` to remove references to the deleted helper. Verify with static Bash checks.

## Concrete Steps

Work from the repo root.

1. Edit `scripts/lib.sh` to remove `docker_compose_run_checked`.
2. Update the following call sites:
   - `run-ralph.sh`: replace `docker_compose_run_checked` with `docker_compose_checked run --rm ...`.
   - `afk-ralph.sh`: replace `docker_compose_run_checked` with `docker_compose_checked run --rm ...`.
   - `authenticate-codex.sh`: replace `docker_compose_run_checked` with `docker_compose_checked run --rm ...`.
3. Update `ARCHITECTURE.md` to remove references to `docker_compose_run_checked` and describe the single helper.
4. Run static Bash syntax checks.

## Validation and Acceptance

Acceptance is met when all of the following are true:

- `rg "docker_compose_run_checked" -n` returns no matches.
- `rg "docker_compose_checked" -n` shows the helper definition in `scripts/lib.sh` and usage in all three entrypoints.
- `bash -n run-ralph.sh afk-ralph.sh authenticate-codex.sh scripts/lib.sh` completes with exit code 0.

Milestone verification workflow:

1. Tests to write: none. This is a shell refactor validated via static checks.
2. Implementation: perform the edits described above.
3. Verification: run the commands listed in the acceptance criteria and confirm output/exit codes.
4. Commit: after verification passes, commit with a message like `Milestone 1: consolidate docker compose helper`.

## Idempotence and Recovery

These edits are safe to apply more than once because they only change helper call sites. If behavior changes unexpectedly, reintroduce `docker_compose_run_checked` and re-run static checks to isolate the issue.

## Artifacts and Notes

    rg "docker_compose_checked" -n scripts/lib.sh run-ralph.sh afk-ralph.sh authenticate-codex.sh
    afk-ralph.sh:9:  docker_compose_checked run --rm -e RALPH_IN_DOCKER=1 ralph ./afk-ralph.sh "$@"
    run-ralph.sh:37:docker_compose_checked run --rm \
    authenticate-codex.sh:8:docker_compose_checked build
    authenticate-codex.sh:11:docker_compose_checked run --rm ralph /workspace/docker/codex-setup.sh
    scripts/lib.sh:127:docker_compose_checked() {

    bash -n run-ralph.sh afk-ralph.sh authenticate-codex.sh scripts/lib.sh

## Interfaces and Dependencies

`scripts/lib.sh` must expose only `docker_compose_checked` as the shared Docker Compose helper. Call sites must pass explicit subcommands like `run --rm` or `build`.

Plan update note: Marked progress complete and recorded verification artifacts after consolidating Docker Compose helpers.
