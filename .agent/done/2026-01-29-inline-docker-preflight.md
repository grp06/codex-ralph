# Consolidate Docker preflight helpers into docker_compose_checked

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

Maintained according to: .agent/PLANS.md

## Purpose / Big Picture

The repo currently exposes three Docker preflight helpers in `scripts/lib.sh`: `require_docker`, `require_docker_compose`, and `require_docker_env`. These helpers are now only used internally by `docker_compose_checked`, so they add extra surface area without additional reuse. After this change, `docker_compose_checked` will inline the preflight checks and the three unused helpers will be removed. This reduces the helper API while preserving the same error messages and behavior whenever Docker or Docker Compose are missing.

## Progress

- [x] (2026-01-29 05:30Z) Inline Docker preflight checks into `docker_compose_checked` and remove `require_docker`, `require_docker_compose`, and `require_docker_env`.
- [x] (2026-01-29 05:30Z) Update documentation references and verify static Bash checks.

## Surprises & Discoveries

- Observation: `require_docker`, `require_docker_compose`, and `require_docker_env` are only used by `docker_compose_checked`.
  Evidence: `rg "require_docker\b|require_docker_compose\b|require_docker_env\b" -n` shows definitions plus a single call chain in `scripts/lib.sh`.

## Decision Log

- Decision: Inline Docker preflight checks into `docker_compose_checked` and remove the unused helpers.
  Rationale: Reduces helper surface area without changing output or behavior.
  Date/Author: 2026-01-29 / Codex

## Outcomes & Retrospective

Docker preflight checks now live directly inside `docker_compose_checked`, and the redundant helpers were removed. Documentation was updated and static Bash checks pass.

## Context and Orientation

`scripts/lib.sh` provides shared helpers used by host entrypoints. `docker_compose_checked` is the only public Docker Compose helper now used at call sites; it currently calls `require_docker_env`, which in turn calls `require_docker` and `require_docker_compose`. Since no other file uses those helper names, they can be collapsed into `docker_compose_checked` while keeping the same error messages and exit behavior.

## Plan of Work

Move the logic from `require_docker` and `require_docker_compose` into `docker_compose_checked` directly, preserving the exact error messages. Remove `require_docker_env` and the two lower-level helpers. Update `ARCHITECTURE.md` to remove mentions of these helpers, keeping the documentation aligned with the remaining helper surface. Verify with static Bash syntax checks.

## Concrete Steps

Work from the repo root.

1. Edit `scripts/lib.sh` to inline the `command -v docker` and `docker compose version` checks into `docker_compose_checked`, preserving the error messages.
2. Remove the `require_docker`, `require_docker_compose`, and `require_docker_env` function definitions.
3. Update `ARCHITECTURE.md` to remove references to `require_docker_env` (and any mention of the removed helpers), while keeping the description of `docker_compose_checked` intact.
4. Run static Bash syntax checks.

## Validation and Acceptance

Acceptance is met when all of the following are true:

- `rg "require_docker\b|require_docker_compose\b|require_docker_env\b" -n` shows no matches in `scripts/lib.sh`.
- `rg "docker_compose_checked" -n scripts/lib.sh` shows the helper still defined and containing the preflight checks.
- `bash -n scripts/lib.sh` completes with exit code 0.

Milestone verification workflow:

1. Tests to write: none. This is a shell refactor validated via static checks.
2. Implementation: perform the edits described above.
3. Verification: run the commands listed in the acceptance criteria and confirm output/exit codes.
4. Commit: after verification passes, commit with a message like `Milestone 1: inline docker preflight checks`.

## Idempotence and Recovery

These edits are safe to apply more than once because they only remove redundant helpers. If behavior changes unexpectedly, reintroduce the helpers with their previous implementations and re-run static checks to isolate the issue.

## Artifacts and Notes

    rg "require_docker\\b|require_docker_compose\\b|require_docker_env\\b" -n scripts/lib.sh
    (no matches)

    bash -n scripts/lib.sh

## Interfaces and Dependencies

`scripts/lib.sh` must expose only `docker_compose_checked` for Docker preflight + Compose invocation. `require_docker`, `require_docker_compose`, and `require_docker_env` should no longer exist.

Plan update note: Marked progress complete and recorded verification artifacts after inlining Docker preflight checks.
