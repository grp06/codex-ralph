# Consolidate usage errors with shared helpers

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

Maintained according to: .agent/PLANS.md

## Purpose / Big Picture

Several scripts emit usage errors (wrong arguments) by repeating the same pattern: log a message and `exit 1`. This is duplicated in `scripts/preflight-deps.sh` and is a good fit for a shared helper. After this change, usage errors will be handled via a shared function in `scripts/lib.sh`, keeping the behavior identical but reducing boilerplate. Users should see the exact same error text and exit status as before.

## Progress

- [x] (2026-01-29 05:00Z) Add a shared usage-error helper in `scripts/lib.sh`.
- [x] (2026-01-29 05:00Z) Replace the inline usage check in `scripts/preflight-deps.sh` with the helper.
- [x] (2026-01-29 05:00Z) Verify static Bash checks and confirm error messages remain unchanged.

## Surprises & Discoveries

- Observation: Only `scripts/preflight-deps.sh` still had an inline usage check; `init-project.sh` relies on `resolve_project_path` without an argument-count guard.
  Evidence: No `if [[ "$#" -lt ... ]]` exists in `init-project.sh`, but one exists in `scripts/preflight-deps.sh`.

## Decision Log

- Decision: Add `require_args` in `scripts/lib.sh` and use it for usage errors.
  Rationale: Centralizes usage handling and avoids repeated log/exit boilerplate without changing output.
  Date/Author: 2026-01-29 / Codex
- Decision: Limit usage-helper adoption to `scripts/preflight-deps.sh` because `init-project.sh` intentionally allows a zero-argument path (via config).
  Rationale: Adding an arg-count guard would change behavior; the helper is still useful where a minimum arg count is required.
  Date/Author: 2026-01-29 / Codex

## Outcomes & Retrospective

Usage handling is now centralized for `scripts/preflight-deps.sh` via `require_args`. `init-project.sh` remains unchanged to preserve its config-based behavior. Static Bash checks pass.

## Context and Orientation

`scripts/preflight-deps.sh` validates argument counts early and exits with a usage message when invoked incorrectly. It sources `scripts/lib.sh`, so a shared helper can be used without changing execution flow. `init-project.sh` does not enforce a minimum argument count because it can resolve a target repo from configuration, so it should not gain a strict usage guard.

## Plan of Work

Add `require_args <min> <actual> <message>` to `scripts/lib.sh`. It should log the message (using `log_error`) and `exit 1` when `actual < min`. Update `scripts/preflight-deps.sh` to call this helper instead of its inline `if [[ "$#" -lt ... ]]` block. Keep the usage message string unchanged. Leave `init-project.sh` alone to preserve its config-based flow.

## Concrete Steps

Work from the repo root.

1. Edit `scripts/lib.sh` to add `require_args`.
2. Update `scripts/preflight-deps.sh` to replace the usage check with `require_args 2 "$#" "Usage: preflight-deps.sh <target-dir> <run-dir>"`.
3. Run static Bash syntax checks.

## Validation and Acceptance

Acceptance is met when all of the following are true:

- `rg "require_args" -n` shows the helper defined in `scripts/lib.sh` and used in `scripts/preflight-deps.sh`.
- `rg "Usage:" -n scripts/preflight-deps.sh` shows the same usage text as before.
- `bash -n scripts/preflight-deps.sh scripts/lib.sh` completes with exit code 0.

Milestone verification workflow:

1. Tests to write: none. This is a shell refactor validated via static checks.
2. Implementation: perform the edits described above.
3. Verification: run the commands listed in the acceptance criteria and confirm output/exit codes.
4. Commit: after verification passes, commit with a message like `Milestone 1: consolidate usage checks`.

## Idempotence and Recovery

These edits are safe to apply more than once because they only change helper call sites. If a script fails after the change, restore the original inline usage check and re-run static checks to isolate the issue.

## Artifacts and Notes

    rg "require_args" -n scripts/lib.sh scripts/preflight-deps.sh
    scripts/lib.sh:47:require_args() {
    scripts/preflight-deps.sh:8:require_args 2 "$#" "Usage: preflight-deps.sh <target-dir> <run-dir>"

    bash -n scripts/preflight-deps.sh scripts/lib.sh

## Interfaces and Dependencies

`scripts/lib.sh` must export `require_args` that logs a provided usage message and exits with status 1 when the argument count is too low.

Plan update note: Adjusted scope to `scripts/preflight-deps.sh` only after confirming `init-project.sh` intentionally supports zero-argument execution.
