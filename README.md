# Ralph Loop (Codex ExecPlans)

Ralph turns Codex into a durable, long-running teammate: point it at any repo, give it a living ExecPlan, and let it chip away at the work safely and methodically.

It’s long-running because Ralph persists “working memory” into files and git, not the chat:
- The ExecPlan (`.agent/execplans/execplan.md`) is the source of truth: Progress, decisions, discoveries, next steps, and validation commands live there and get updated every iteration.
- Each loop iteration makes a small change, runs the plan’s validation, and commits—so the repo history becomes an audit log and a safe checkpoint/rollback mechanism.
- The runner also saves per-iteration logs and the agent’s structured output under `runs/<project>/.ralph/`, so you can resume after interruptions and see what happened.

## Quick start
1) Build the image, install Codex CLI, and authenticate:

```bash
./authenticate-codex.sh
```

2) Initialize the target repo (or set `target_repo_path` in `ralph.config.toml` and run without arguments):

```bash
./init-project.sh /path/to/project
```

Example config:

```
target_repo_path = "/Users/you/my-repo"
```

3) Edit the plan:

```
/path/to/project/.agent/execplans/execplan.md
```

4) Run the loop (defaults to running until Progress is complete):

```bash
./run-ralph.sh /path/to/project
```

## Requirements
- Docker + Docker Compose v2
- Target repo is a git repo
- The loop runs Codex with `--sandbox danger-full-access` (use only in a trusted environment)

## Notes
- Run commands from this repo root.
- Logs and outputs go under `runs/<project>/.ralph/`.
- All code changes and git commands run in the target repo.
