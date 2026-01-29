# Consolidate project-path resolution for host entrypoints

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

Maintained according to: .agent/PLANS.md

## Purpose / Big Picture

Both `run-ralph.sh` and `init-project.sh` perform the same “resolve project path from args or config” sequence using `resolve_target_repo`. This duplicates boilerplate and risks drift in how usage and config are handled. After this change, a single helper in `scripts/lib.sh` will encapsulate the runner-root + config + optional argument handling, and both entrypoints will call it. Users should see the same behavior and error messages when they omit a path or provide an invalid one.

## Progress

- [x] (2026-01-29 04:20Z) Add a shared project-path resolution helper in `scripts/lib.sh` and update entrypoints to use it.
- [x] (2026-01-29 04:20Z) Verify entrypoints still resolve project paths and scripts pass static checks.

## Surprises & Discoveries

- Observation: `run-ralph.sh` and `init-project.sh` both compute `runner_root`, `config_path`, and then call `resolve_target_repo` with the same argument pattern.
  Evidence: `rg "resolve_target_repo" -n *.sh` shows the same call sequence in both scripts.

## Decision Log

- Decision: Add a helper to `scripts/lib.sh` that takes the runner root, optional path argument, and usage function, and returns the resolved project path.
  Rationale: Centralizes the standard path-resolution flow while keeping usage/error handling identical.
  Date/Author: 2026-01-29 / Codex

## Outcomes & Retrospective

Project path resolution is now centralized in `scripts/lib.sh` via `resolve_project_path`, and both entrypoints use it. Static Bash checks pass with no errors.

## Context and Orientation

This repo uses Bash entrypoints to drive the Ralph loop. `resolve_target_repo` in `scripts/lib.sh` already handles reading `ralph.config.toml`, expanding `~`, and validating the target repo. `run-ralph.sh` and `init-project.sh` both build the same `config_path` and pass `arg_path` to `resolve_target_repo`. The goal is to consolidate that boilerplate into a single helper so future changes to config path handling only happen in one place.

## Plan of Work

Add a small helper in `scripts/lib.sh` (for example `resolve_project_path`) that accepts `runner_root`, `arg_path`, and an optional `usage` function name, then calls `resolve_target_repo` with the correct config path. Update `run-ralph.sh` and `init-project.sh` to use the helper, keeping their argument parsing (including the `shift` behavior in `run-ralph.sh`) intact. Verify with static checks.

## Concrete Steps

Work from the repo root.

1. Edit `scripts/lib.sh` to add a helper (e.g., `resolve_project_path`) that constructs `config_path="$runner_root/ralph.config.toml"` and returns `resolve_target_repo "$arg_path" "$config_path" "$usage_fn"`.
2. Edit `run-ralph.sh` to replace the direct `resolve_target_repo` call and remove the standalone `config_path` variable, calling the new helper instead.
3. Edit `init-project.sh` similarly to use the helper and remove its standalone `config_path` variable.
4. Run static Bash syntax checks.

## Validation and Acceptance

Acceptance is met when all of the following are true:

- `rg "config_path=\"\$runner_root/ralph.config.toml\"" -n` shows no matches in `run-ralph.sh` or `init-project.sh`.
- `rg "resolve_project_path" -n` shows the helper defined in `scripts/lib.sh` and used in both entrypoints.
- `bash -n run-ralph.sh init-project.sh scripts/lib.sh` completes with exit code 0.

Milestone verification workflow:

1. Tests to write: none. This is a shell refactor validated via static checks.
2. Implementation: perform the edits described above.
3. Verification: run the commands listed in the acceptance criteria and confirm output/exit codes.
4. Commit: after verification passes, commit with a message like `Milestone 1: consolidate project path resolution`.

## Idempotence and Recovery

These edits are safe to apply more than once because they only change helper call sites. If an entrypoint fails after the change, restore its original call and re-run the static checks to isolate the issue.

## Artifacts and Notes

    rg "resolve_project_path" -n run-ralph.sh init-project.sh scripts/lib.sh
    run-ralph.sh:18:project_path="$(resolve_project_path "$runner_root" "$arg_path" usage)"
    init-project.sh:17:project_path="$(resolve_project_path "$runner_root" "$arg_path" usage)"
    scripts/lib.sh:84:resolve_project_path() {

    bash -n run-ralph.sh init-project.sh scripts/lib.sh

## Interfaces and Dependencies

`scripts/lib.sh` must export a helper named `resolve_project_path` that takes `(runner_root, arg_path, usage_fn)` and returns the resolved project path by calling `resolve_target_repo` with the computed config path.

Plan update note: Marked progress complete and recorded verification artifacts after consolidating project path resolution.
