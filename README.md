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
- `ralph.schema.json`: JSON schema for structured loop output.
- `ralph-once.sh`: Run one iteration (human-in-the-loop).
- `afk-ralph.sh`: Run multiple iterations (unattended).
- `.ralph/last.json`: Last structured output (ignored by git).

## Requirements
- OpenAI Codex CLI installed and authenticated (`codex`).
- `git` initialized (each iteration commits).
- `jq` installed (used by `afk-ralph.sh`).
- The loop scripts run Codex with `--sandbox danger-full-access` so the agent can commit (run only in a trusted environment).

## Quick start
1) Write your plan in `EXECPLAN.md` (fill in Purpose, Progress, Validation, etc.).
2) Run one iteration:

```bash
./ralph-once.sh
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
