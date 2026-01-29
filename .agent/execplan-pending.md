# Consolidate Shared Shell Helpers

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

Maintained according to: .agent/PLANS.md

## Purpose / Big Picture

Reduce duplicate Bash helper functions by consolidating logging, config parsing, path expansion, and Docker checks into `scripts/lib.sh`, then sourcing that library from the entrypoint scripts. After this change, updating a helper (for example, log formatting or Docker checks) happens in one place, and all runner scripts stay behaviorally consistent. You can see it working by running syntax checks plus a small smoke run of `./init-project.sh` against a temporary git repo; the scripts should behave exactly as before, just with shared helpers.

## Progress

- [x] (2026-01-29 03:47Z) Wire `scripts/lib.sh` into `run-ralph.sh` and `init-project.sh`, removing duplicated helpers and preserving behavior.
- [ ] (2026-01-29 00:00Z) Wire `scripts/lib.sh` into `authenticate-codex.sh`, `docker/run.sh`, and `scripts/preflight-deps.sh`, removing duplicated logging and Docker checks.
- [ ] (2026-01-29 00:00Z) Run validation commands and record results in this plan.

## Surprises & Discoveries

- Observation: `run-ralph.sh` calls `log_warn` but only defines `log_info` and `log_error`, so the warning path relies on a missing function.
  Evidence: `run-ralph.sh` uses `log_warn` when no iteration cap is set.

## Decision Log

- Decision: Consolidate shared helpers into `scripts/lib.sh` and source it from the runner scripts instead of maintaining duplicated functions.
  Rationale: This removes dead duplication, fixes the missing `log_warn` in `run-ralph.sh`, and makes future changes lower-risk.
  Date/Author: 2026-01-29 / Codex

## Outcomes & Retrospective

- Pending.

## Context and Orientation

The repo is a Bash-based runner for Codex. The main entrypoints are `run-ralph.sh` (runs the loop inside Docker), `afk-ralph.sh` (invokes Codex inside the container), `authenticate-codex.sh` (builds the image and installs/authenticates Codex), and `init-project.sh` (copies `templates/PLANS.md` into a target repo). Supporting scripts live in `scripts/` and `docker/`. There is already a shared helper library at `scripts/lib.sh` that defines logging, config parsing, path expansion, and Docker checks, but it is not sourced anywhere. Multiple scripts re-define the same helpers, which is the main source of duplication.

## Plan of Work

Update the runner scripts to source `scripts/lib.sh` and remove their local definitions of shared helpers. Keep script-specific functions (such as `usage`) where they are. Ensure pathing is correct for scripts in subdirectories (`docker/` and `scripts/`) by computing `SCRIPT_DIR` and sourcing the library using a relative path. For `run-ralph.sh` and `init-project.sh`, replace the inline `read_config_value` and `expand_path` implementations with the library versions. For Docker checks, replace inline `command -v docker` and `docker compose` checks with `require_docker` and `require_docker_compose` from the library. Do not touch `afk-ralph.sh` since it has its own colorized logging and higher complexity.

## Concrete Steps

1) Edit `scripts/lib.sh` only if a helper is missing for the calling scripts. Otherwise leave it as-is.

2) Update `run-ralph.sh` and `init-project.sh` to source the library and delete their duplicate `log_*`, `read_config_value`, and `expand_path` definitions. Keep `usage` in each file.

3) Update `authenticate-codex.sh`, `docker/run.sh`, and `scripts/preflight-deps.sh` to source the library and delete duplicate `log_*` functions and Docker checks, replacing them with `require_docker` and `require_docker_compose` where applicable.

4) Validation commands (run from repo root `/Users/georgepickett/ralph-new`):

    bash -n run-ralph.sh init-project.sh authenticate-codex.sh docker/run.sh scripts/preflight-deps.sh scripts/lib.sh

    tmpdir="$(mktemp -d /tmp/ralph-init-XXXXXX)"
    git -C "$tmpdir" init
    ./init-project.sh "$tmpdir"
    test -f "$tmpdir/.agent/PLANS.md"
    test -f "$tmpdir/.agent/execplans/execplan.md"

    # Optional if Docker is available and configured:
    ./docker/run.sh true

Record any output or errors in the `Artifacts and Notes` section.

## Validation and Acceptance

The change is accepted when:

- `scripts/lib.sh` is the single source of `log_info`, `log_warn`, `log_error`, `read_config_value`, `expand_path`, `require_docker`, and `require_docker_compose` for the scripts updated in this plan.
- No updated script defines duplicate versions of those helpers.
- `run-ralph.sh` can call `log_warn` without a missing-function error.
- `bash -n` passes for all modified scripts.
- Running `./init-project.sh` against a fresh temporary git repo creates `.agent/PLANS.md` and `.agent/execplans/execplan.md` as before.
- If Docker is available, `./docker/run.sh true` prints the "Running in Docker" message and exits successfully.

For each milestone, use this verification workflow:

Milestone 1:
  1. Tests to write: none (no test harness). Use syntax and smoke checks instead.
  2. Implementation: update `run-ralph.sh` and `init-project.sh` to source `scripts/lib.sh` and remove duplicate helpers.
  3. Verification: run `bash -n` on the two scripts; run the `./init-project.sh` smoke test with a temporary git repo.
  4. Commit: after verification passes, commit with message "Milestone 1: centralize helpers in core scripts".

Milestone 2:
  1. Tests to write: none (no test harness). Use syntax and smoke checks instead.
  2. Implementation: update `authenticate-codex.sh`, `docker/run.sh`, and `scripts/preflight-deps.sh` to source `scripts/lib.sh` and remove duplicate helpers; replace inline Docker checks with library functions.
  3. Verification: run `bash -n` on these scripts; if Docker is available, run `./docker/run.sh true`.
  4. Commit: after verification passes, commit with message "Milestone 2: centralize helpers in docker and preflight scripts".

## Idempotence and Recovery

These edits are safe to re-apply. If a script fails after the refactor, recover by temporarily restoring its previous local helper definitions and re-running the validation commands to isolate the missing function or path issue. The changes do not alter data or external state beyond normal script execution.

## Artifacts and Notes

- Add short transcripts of the validation commands here as they are run.
- If any script emits unexpected errors after sourcing `scripts/lib.sh`, capture the exact error message and the file path.
    bash -n run-ralph.sh init-project.sh
    (no output; exit 0)

    ./init-project.sh "$tmpdir"
    [INFO] Created /tmp/ralph-init-KMy7E4/.agent/PLANS.md
    [INFO] Created /tmp/ralph-init-KMy7E4/.agent/execplans/execplan.md
    [INFO] Edit the ExecPlan, then run ./run-ralph.sh "/tmp/ralph-init-KMy7E4"

## Interfaces and Dependencies

`scripts/lib.sh` must continue to expose these functions and signatures:

- `log_info "message"`, `log_warn "message"`, `log_error "message"` for consistent logging.
- `read_config_value "key" "config_path"` to read `ralph.config.toml`.
- `expand_path "path"` to expand a leading `~`.
- `require_docker` and `require_docker_compose` for Docker checks.

Scripts that source the library must compute their own `SCRIPT_DIR` (or equivalent) to locate `scripts/lib.sh` reliably when run from any working directory.
