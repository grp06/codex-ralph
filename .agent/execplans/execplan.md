# Consolidate Shared Shell Helpers

This ExecPlan is a living document. The sections `Progress`, `Surprises & Discoveries`, `Decision Log`, and `Outcomes & Retrospective` must be kept up to date as work proceeds.

Maintained according to: .agent/PLANS.md

## Purpose / Big Picture

The shell scripts in this repo repeat the same logging helpers, Docker checks, and config parsing. After this change, a single shared helper file will provide those behaviors, reducing drift risk and simplifying future changes. A user can verify the change by running the same commands as before and observing identical output and exit behavior.

## Progress

- [x] (2026-01-29 00:30Z) Add a shared helper module at `scripts/lib.sh` with logging, config parsing, and Docker checks.
- [ ] (2026-01-29 00:00Z) Update the existing scripts to source `scripts/lib.sh` and remove duplicate helper definitions.
- [ ] (2026-01-29 00:00Z) Verify behavior with syntax checks and smoke runs of the main entry scripts.

## Surprises & Discoveries

- Observation: `./run-ralph.sh` failed early because the Docker daemon is not running, so it did not reach the usage/missing-path error.
  Evidence: "Cannot connect to the Docker daemon at unix:///Users/georgepickett/.docker/run/docker.sock."
- Observation: `./init-project.sh` did not print usage because `ralph.config.toml` provides a target repo path.
  Evidence: It reported existing `.agent/` files under `/Users/georgepickett/my-crm`.

## Decision Log

- Decision: Centralize common shell helpers in `scripts/lib.sh` and source it from all entry scripts.
  Rationale: The same helper logic appears in multiple files, and consolidating it reduces maintenance burden with a low blast radius.
  Date/Author: 2026-01-29 / Codex

## Outcomes & Retrospective

- Outcome: Not started.
- What remains: Implement the shared helper and update scripts.
- Lessons: TBD.

## Context and Orientation

This repo is a runner for a long-running agent loop. The main entry points are `run-ralph.sh` (host runner), `init-project.sh` (bootstraps a target repo with .agent files), and `authenticate-codex.sh` (builds the Docker image and authenticates). The Docker wrapper script `docker/run.sh` is used to execute commands inside the container. The container loop lives in `afk-ralph.sh`. A preflight dependency installer lives at `scripts/preflight-deps.sh`. These scripts currently duplicate logging functions and Docker checks. We will add a new shared file at `scripts/lib.sh` and have the scripts source it using a path derived from `BASH_SOURCE` so it is robust when run from different working directories.

Define terms used below:

- "Host script" means a script run on the developer machine outside the container (for example, `run-ralph.sh`).
- "Container script" means a script run inside the Docker container (for example, `docker/codex-setup.sh`).

## Plan of Work

First, create `scripts/lib.sh` with shared helpers for logging, reading config values from `ralph.config.toml`, expanding `~` in paths, and enforcing Docker and Docker Compose availability. Then update each script that currently redefines these helpers to source `scripts/lib.sh` and remove local duplicates. Finally, verify the changes by running shell syntax checks and small smoke runs to confirm usage messages and error handling still work.

## Concrete Steps

Work from the repository root `/Users/georgepickett/ralph-new`.

1. Create `scripts/lib.sh` with the shared helpers. Include these functions with the described behavior:

   - `log_info`, `log_warn`, `log_error`: format as `[INFO]`, `[WARN]`, `[ERR]` with the message, matching current output style.
   - `read_config_value <key> <config_path>`: parse a `key = "value"` line from TOML and print the value or an empty string if not found.
   - `expand_path <path>`: replace a leading `~` with `$HOME`.
   - `require_docker`: exit with a clear error message if `docker` is missing.
   - `require_docker_compose`: exit with a clear error message if `docker compose` is missing.

   Keep the functions simple and compatible with `bash` (these scripts already rely on bash).

2. Update these files to source `scripts/lib.sh` and delete their local duplicates:

   - `run-ralph.sh`
   - `init-project.sh`
   - `authenticate-codex.sh`
   - `docker/run.sh`
   - `docker/codex-setup.sh`
   - `scripts/preflight-deps.sh`

   Use a `SCRIPT_DIR` pattern based on `BASH_SOURCE[0]` to locate `scripts/lib.sh` by absolute path so sourcing works regardless of the current working directory. In `docker/codex-setup.sh`, make sure the path resolves inside the container (the repo is mounted at `/workspace`).

3. Verify syntax and behavior:

   - Run `bash -n` on every modified script and confirm zero output and exit code 0.
   - Run `./run-ralph.sh` without arguments and confirm it prints a usage message and a missing project path error.
   - Run `./init-project.sh` without arguments and confirm it prints a usage message and a missing project path error.
   - If Docker is available, run `./docker/run.sh /bin/true` and confirm it exits 0.

## Validation and Acceptance

Acceptance is met when:

- All scripts source `scripts/lib.sh` and no longer define their own logging or Docker-check helpers.
- Running `bash -n` on modified scripts reports no syntax errors.
- The usage and error messages for `run-ralph.sh` and `init-project.sh` still appear as before for missing arguments.
- The Docker wrapper still runs a command successfully when Docker is installed.

Verification workflow for the single milestone:

1. Tests to write: Not applicable; this repo does not contain a test harness for shell scripts. Use the verification commands below instead.
2. Implementation: Add `scripts/lib.sh`, source it in the listed scripts, and remove duplicated helpers.
3. Verification: Run the commands below and confirm they behave as described.
4. Commit: After verification passes, commit with message "Milestone 1: consolidate shell helpers".

Verification commands (run from repo root):

    bash -n run-ralph.sh init-project.sh authenticate-codex.sh afk-ralph.sh docker/run.sh docker/codex-setup.sh scripts/preflight-deps.sh
    ./run-ralph.sh
    ./init-project.sh
    ./docker/run.sh /bin/true

Expected results:

- `bash -n` returns exit code 0 with no output.
- `./run-ralph.sh` prints usage and a missing project path error, then exits nonzero.
- `./init-project.sh` prints usage and a missing project path error, then exits nonzero.
- `./docker/run.sh /bin/true` exits 0 when Docker is installed.

## Idempotence and Recovery

These changes are additive and safe to re-run. If sourcing `scripts/lib.sh` fails, restore the prior helper definitions from version control or re-add the local helpers and re-run the syntax checks before attempting the consolidation again.

## Artifacts and Notes

Verification transcripts:

    $ bash -n run-ralph.sh init-project.sh authenticate-codex.sh afk-ralph.sh docker/run.sh docker/codex-setup.sh scripts/preflight-deps.sh
    $ echo $?
    0

    $ ./run-ralph.sh
    Cannot connect to the Docker daemon at unix:///Users/georgepickett/.docker/run/docker.sock. Is the docker daemon running?

    $ ./init-project.sh
    [INFO] PLANS.md already exists at /Users/georgepickett/my-crm/.agent/PLANS.md
    [INFO] ExecPlan already exists at /Users/georgepickett/my-crm/.agent/execplans/execplan.md
    [INFO] Edit the ExecPlan, then run ./run-ralph.sh "/Users/georgepickett/my-crm"

    $ ./docker/run.sh /bin/true
    [INFO] Running in Docker.
    Cannot connect to the Docker daemon at unix:///Users/georgepickett/.docker/run/docker.sock. Is the docker daemon running?

## Interfaces and Dependencies

In `scripts/lib.sh`, define the following functions exactly, with these signatures:

    log_info "message"
    log_warn "message"
    log_error "message"
    read_config_value "key" "config_path"
    expand_path "path"
    require_docker
    require_docker_compose

No external dependencies are required beyond `bash`, `awk`, and standard Unix tools already used in the repo.

## Plan Update Notes

Updated Progress to mark the shared helper module creation complete after adding `scripts/lib.sh`, and captured validation output in Surprises and Artifacts.
