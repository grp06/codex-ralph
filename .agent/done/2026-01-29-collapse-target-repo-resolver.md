# Collapse resolve_target_repo into resolve_project_path

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

Maintained according to: .agent/PLANS.md

## Purpose / Big Picture

The shared helper `resolve_target_repo` is now only called by `resolve_project_path`. That makes the two-step indirection unnecessary and adds a redundant concept. After this change, `resolve_project_path` will contain the full resolution logic and `resolve_target_repo` will be removed. Entry points will continue to call `resolve_project_path` with no behavior change, and error messages for missing or invalid project paths must stay identical.

## Progress

- [x] (2026-01-29 04:55Z) Inline `resolve_target_repo` logic into `resolve_project_path` and remove `resolve_target_repo`.
- [x] (2026-01-29 04:55Z) Update documentation references and verify static Bash checks.

## Surprises & Discoveries

- Observation: `resolve_target_repo` is only used by `resolve_project_path`.
  Evidence: `rg "resolve_target_repo" -n` shows only the definition and a single call inside `scripts/lib.sh`.

## Decision Log

- Decision: Collapse `resolve_target_repo` into `resolve_project_path` and remove the unused helper.
  Rationale: Reduces surface area and keeps the public API limited to a single project-path resolver.
  Date/Author: 2026-01-29 / Codex

## Outcomes & Retrospective

`resolve_target_repo` has been removed and its logic now lives in `resolve_project_path`. Documentation has been updated, and static Bash checks pass.

## Context and Orientation

`scripts/lib.sh` provides shared helpers. `resolve_project_path` currently computes `config_path` and delegates to `resolve_target_repo`, which performs the actual path resolution and validation. Only `run-ralph.sh` and `init-project.sh` call `resolve_project_path`. The goal is to move the resolution logic directly into `resolve_project_path` and delete the unused `resolve_target_repo` function, keeping behavior and error messages unchanged.

## Plan of Work

Move the body of `resolve_target_repo` into `resolve_project_path`, keeping the same logic and error messages, and remove the `resolve_target_repo` function. Update `ARCHITECTURE.md` to reference `resolve_project_path` as the target repo resolution helper. Validate with static Bash checks.

## Concrete Steps

Work from the repo root.

1. Edit `scripts/lib.sh` to inline the logic from `resolve_target_repo` into `resolve_project_path` and remove `resolve_target_repo` entirely.
   - Preserve all error messages and exit paths exactly.
2. Update `ARCHITECTURE.md` to replace mentions of `resolve_target_repo` with `resolve_project_path` where it describes target repo resolution.
3. Run static Bash syntax checks.

## Validation and Acceptance

Acceptance is met when all of the following are true:

- `rg "resolve_target_repo" -n scripts/lib.sh run-ralph.sh init-project.sh` shows no matches.
- `rg "resolve_project_path" -n scripts/lib.sh run-ralph.sh init-project.sh` shows the helper definition and call sites only.
- `bash -n run-ralph.sh init-project.sh scripts/lib.sh` completes with exit code 0.

Milestone verification workflow:

1. Tests to write: none. This is a shell refactor validated via static checks and unchanged error messages.
2. Implementation: perform the edits described above.
3. Verification: run the commands listed in the acceptance criteria and confirm output/exit codes.
4. Commit: after verification passes, commit with a message like `Milestone 1: collapse target repo resolver`.

## Idempotence and Recovery

These edits are safe to apply more than once because they only consolidate helper logic. If behavior changes unexpectedly, restore the previous `resolve_target_repo` function and re-run static checks to isolate the issue.

## Artifacts and Notes

    rg "resolve_target_repo" -n scripts/lib.sh run-ralph.sh init-project.sh
    (no matches)

    bash -n run-ralph.sh init-project.sh scripts/lib.sh

## Interfaces and Dependencies

`scripts/lib.sh` must expose only `resolve_project_path` as the project-path resolver; `resolve_target_repo` should no longer exist.

Plan update note: Marked progress complete and recorded verification artifacts after collapsing the target repo resolver.
