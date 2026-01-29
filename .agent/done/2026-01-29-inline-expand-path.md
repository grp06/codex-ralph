# Inline expand_path into resolve_project_path

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

Maintained according to: .agent/PLANS.md

## Purpose / Big Picture

The helper `expand_path` in `scripts/lib.sh` is only used inside `resolve_project_path`, so it adds an extra abstraction without broader reuse. After this change, `resolve_project_path` will handle the `~` expansion directly and `expand_path` will be removed. This reduces helper surface area while keeping the same behavior for resolving target repo paths from configuration.

## Progress

- [x] (2026-01-29 05:04Z) Inline `expand_path` logic into `resolve_project_path` and remove the helper.
- [x] (2026-01-29 05:04Z) Update documentation references and verify static Bash checks.

## Surprises & Discoveries

- Observation: `expand_path` is only referenced from within `resolve_project_path`.
  Evidence: `rg "expand_path" -n` shows the function definition and a single call in `scripts/lib.sh`.

## Decision Log

- Decision: Remove `expand_path` and inline its logic into `resolve_project_path`.
  Rationale: Eliminates a single-use helper and keeps the path-resolution logic in one place.
  Date/Author: 2026-01-29 / Codex

## Outcomes & Retrospective

`expand_path` has been removed and its `~` expansion logic now lives inside `resolve_project_path`. Documentation was updated and static Bash checks pass.

## Context and Orientation

`scripts/lib.sh` contains shared helpers. `resolve_project_path` reads `target_repo_path` from `ralph.config.toml`, then calls `expand_path` to expand `~`. The expansion logic itself is a short `if` block. The goal is to keep this logic inside `resolve_project_path` and remove the redundant helper.

## Plan of Work

Move the body of `expand_path` into `resolve_project_path` immediately after reading the config value. Remove the `expand_path` function definition. Update `ARCHITECTURE.md` to remove or adjust references to `expand_path`, noting that path expansion occurs inside `resolve_project_path`. Verify with static Bash checks.

## Concrete Steps

Work from the repo root.

1. Edit `scripts/lib.sh` to inline the `~` expansion logic in `resolve_project_path` and delete the `expand_path` function.
2. Update `ARCHITECTURE.md` to remove `expand_path` references and describe expansion as part of `resolve_project_path`.
3. Run static Bash syntax checks.

## Validation and Acceptance

Acceptance is met when all of the following are true:

- `rg "expand_path" -n scripts/lib.sh` shows no matches.
- `rg "resolve_project_path" -n scripts/lib.sh run-ralph.sh init-project.sh` still shows the helper and call sites.
- `bash -n run-ralph.sh init-project.sh scripts/lib.sh` completes with exit code 0.

Milestone verification workflow:

1. Tests to write: none. This is a shell refactor validated via static checks.
2. Implementation: perform the edits described above.
3. Verification: run the commands listed in the acceptance criteria and confirm output/exit codes.
4. Commit: after verification passes, commit with a message like `Milestone 1: inline expand_path`.

## Idempotence and Recovery

These edits are safe to apply more than once because they only remove a thin helper. If behavior changes unexpectedly, reintroduce `expand_path` with its previous implementation and re-run static checks to isolate the issue.

## Artifacts and Notes

    rg "expand_path" -n scripts/lib.sh
    (no matches)

    bash -n run-ralph.sh init-project.sh scripts/lib.sh

## Interfaces and Dependencies

`scripts/lib.sh` must no longer expose `expand_path`; `resolve_project_path` must handle `~` expansion internally.

Plan update note: Marked progress complete and recorded verification artifacts after inlining path expansion.
