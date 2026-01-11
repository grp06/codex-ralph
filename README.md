# Ralph Loop (Codex ExecPlans)

Ralph is a simple agent loop: read a plan, do one small unit of work, validate, commit, and repeat. This repo sets up that loop using the OpenAI Codex CLI and an ExecPlan document.

## How the loop works
Each iteration:
1) Read `.agent/PLANS.md` and `EXECPLAN.md`.
2) Pick the next unchecked Progress item in `EXECPLAN.md` (or split it and do only the first slice).
3) Implement the change.
4) Run the Validation commands listed in `EXECPLAN.md`.
5) Make exactly one git commit.
6) Update `EXECPLAN.md` (Progress + Decision/Discovery notes when relevant).

The loop stops when Progress is fully complete or when blocked (status `BLOCKED`).

## Key files
- `EXECPLAN.md`: The living plan and single source of truth.
- `.agent/PLANS.md`: Rules and template for writing ExecPlans.
- `AGENTS.md`: Repo-level instructions for Codex.
- `Dockerfile` + `docker-compose.yml`: Container runtime for the loop.
- `ralph.schema.json`: JSON schema for structured loop output.
- `afk-ralph.sh`: Run multiple iterations (unattended).
- `ralph-project.sh`: Run the loop against an external project.
- `ralph.config.toml`: Default Codex settings for the loop.
- `docker/init.sh`: Build image, install Codex CLI, authenticate.
- `docker/run.sh`: Run a command inside the container.
- `docker/codex-setup.sh`: Install Codex CLI and prompt for login.
- `templates/EXECPLAN.md`: Template for new project plans.
- `runs/`: Per-project plans, logs, and outputs.
- `.ralph/last.json`: Last structured output (ignored by git).

## Requirements
- Docker + Docker Compose v2.
- `git` initialized (each iteration commits).
- The loop scripts run Codex with `--sandbox danger-full-access` so the agent can commit (run only in a trusted environment).

## Docker setup
1) Build the image, install Codex CLI, and authenticate:

```bash
./docker/init.sh
```

You will be prompted to choose ChatGPT login, device login, or API key auth.

2) Run one iteration:

```bash
./afk-ralph.sh 1
```

3) For unattended runs (cap iterations or omit to run until Progress is complete):

```bash
./afk-ralph.sh 20
```

To open a shell in the container:

```bash
./docker/run.sh bash
```

Auth is stored in `./.ralph/home/.codex/` inside the repo.
Default Codex settings for the loop live in `ralph.config.toml`.

## Run on another project (keeps this repo stable)
This repo can run the loop against a separate target repo without adding Ralph files to that target.

1) Run once:

```bash
./ralph-project.sh /path/to/project 1
```

2) Run unattended:

```bash
./ralph-project.sh /path/to/project 20
```

The first run creates `runs/<project>/EXECPLAN.md` from the template and exits so you can edit it.
Subsequent runs use that plan and write logs/output under `runs/<project>/.ralph/`.
Set `RALPH_PROJECT_NAME` to override the default project name (basename of the path).
Edit the plan before running if this is a new project.
All code changes and git commands run in the target repo.

## Quick start
1) Write your plan in `EXECPLAN.md` (fill in Purpose, Progress, Validation, etc.).
2) Run one iteration:

```bash
./afk-ralph.sh 1
```

3) For unattended runs (cap iterations or omit to run until Progress is complete):

```bash
./afk-ralph.sh 20
```

## CRM app local setup
From repo root:
1) Install dependencies:

```bash
pnpm -C apps/crm install
```

2) Create `apps/crm/.env.local` with:

```bash
NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-local-anon-key
```

3) (Optional) Start local Supabase if using Docker:

```bash
supabase start
```

4) Run the app:

```bash
pnpm -C apps/crm dev
```

## Output and logs
Both scripts print colored status lines for readability. The final structured response is saved to `./.ralph/last.json` and also printed to the terminal.

## Tips
- Keep Progress items small and testable.
- Make Validation commands fast; the loop runs them every iteration.
- If blocked, update `EXECPLAN.md` with the missing info and re-run.
