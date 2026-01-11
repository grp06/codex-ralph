Below is the same “Ralph loop” tutorial, but rebuilt for **OpenAI Codex CLI** using **`codex exec` (non‑interactive / automation mode)** and the **ExecPlans (PLANS.md) pattern** from OpenAI’s cookbook.

---

## 0. What changes vs your Claude/Docker version

* **No `@PRD.md` include syntax.** Codex can read files in the repo; you just tell it which files to open.
* **`codex exec` is already built for scripts/CI.** It streams progress to **stderr** and prints the **final message to stdout**. ([OpenAI Developers][1])
* **Instead of `PRD.md + progress.txt`, use a single living `EXECPLAN.md`.** ExecPlans explicitly include a checkbox **Progress** section plus decision/discovery logs. ([OpenAI Cookbook][2])
* **Don’t use a magic `<promise>` string.** Use `--output-schema` so the final response is machine-parseable JSON. ([OpenAI Developers][1])

---

## 1. Install Codex CLI

Install via npm:

```bash
npm i -g @openai/codex
```

Then run:

```bash
codex
```

First run prompts you to sign in (ChatGPT login or API key). ([OpenAI Developers][3])

---

## 2. Pick your “sandbox + approvals” posture (this matters for loops)

`codex exec` defaults to a **read-only sandbox**. ([OpenAI Developers][1])
For a coding agent loop, you need write access, so choose one of these:

### Human-in-the-loop (recommended first)

Use `--full-auto` (sets sandbox to workspace-write and approvals to on-request). ([OpenAI Developers][4])
Note: `workspace-write` blocks writes to `.git`, so commits will fail unless you switch to `danger-full-access` or move committing outside the agent loop.

### Fully unattended loop (won’t stall on approvals)

Set approvals to never and sandbox to workspace-write:

* For `codex exec`, approvals are set via config override: `-c 'approval_policy=\"never\"'`. ([OpenAI Developers][4])
* `--sandbox workspace-write` allows edits inside the repo. ([OpenAI Developers][4])
* If you need the loop to make git commits, use `--sandbox danger-full-access` instead (it removes the sandbox). ([OpenAI Developers][4])
* If you need network access from the workspace sandbox, enable it via config override: `-c 'sandbox_workspace_write.network_access=true'`. ([OpenAI Developers][4])

If you’re tempted to use `--yolo`: that bypasses approvals *and* sandboxing. Only makes sense if you’re already inside a hardened container/runner. ([OpenAI Developers][4])

---

## 3. Set up ExecPlans scaffolding (OpenAI cookbook pattern)

You want Codex to consistently treat your plan as a first-class artifact.

### 3.1 Add `AGENTS.md` in repo root

Codex reads `AGENTS.md` before doing any work, and merges instruction files from root → current directory. ([OpenAI Developers][5])

Create `AGENTS.md`:

```md
# AGENTS.md

## ExecPlans
When implementing complex features or refactors, use an ExecPlan as defined in .agent/PLANS.md.

## Ralph Loop Rules
- Treat EXECPLAN.md as the source of truth.
- Each run must complete exactly ONE unchecked Progress item (or split it smaller and complete the first slice).
- After changes: run the Validation commands from EXECPLAN.md.
- Make exactly one git commit per run.
- Update EXECPLAN.md (Progress + any decisions/discoveries).
```

The “ExecPlans” idea (AGENTS.md points to `.agent/PLANS.md`) is exactly what the cookbook describes. ([OpenAI Cookbook][2])

### 3.2 Add `.agent/PLANS.md`

Create the folder and file:

```bash
mkdir -p .agent
$EDITOR .agent/PLANS.md
```

Populate `.agent/PLANS.md` by adapting OpenAI’s cookbook “PLANS.md for multi-hour problem solving / ExecPlans” template: it defines what an ExecPlan is, and requires it to be a living, self-contained design doc with sections like Progress, Decision Log, etc. ([OpenAI Cookbook][2])

Don’t paste the cookbook verbatim into your public tutorial if you’re publishing; instead, keep your own version with the same intent and structure.

### 3.3 Create your actual plan: `EXECPLAN.md`

This replaces your old `PRD.md + progress.txt`. ExecPlans already bake in progress tracking via checkboxes + timestamps. ([OpenAI Cookbook][2])

Here’s a lean ExecPlan skeleton that matches the cookbook’s required sections (written in my words, not copied):

```md
# <Short, action-oriented goal>

This ExecPlan is a living document. Keep Progress, Surprises & Discoveries, Decision Log, and Outcomes & Retrospective updated throughout.

Maintained according to: .agent/PLANS.md

## Purpose / Big Picture
What user-visible behavior exists when this is done? How do we observe it working?

## Progress
- [ ] (YYYY-MM-DD) Task 1: ...
- [ ] (YYYY-MM-DD) Task 2: ...
- [ ] (YYYY-MM-DD) Task 3: ...

## Surprises & Discoveries
- Observation:
  Evidence:

## Decision Log
- Decision:
  Rationale:
  Date/Author:

## Outcomes & Retrospective
- Outcome:
- What remains:
- Lessons:

## Context and Orientation
What files matter? Current behavior? Any terms that need defining?

## Plan of Work
Concrete narrative of what changes where.

## Concrete Steps
Exact commands to run, and where.

## Validation and Acceptance
What tests to run? What output signals success?

## Idempotence and Recovery
If a step is risky, how to retry/rollback safely?

## Artifacts and Notes
Small snippets (logs, diffs) that prove progress.

## Interfaces and Dependencies
If you’re adding public APIs/types, specify names and signatures.
```

This matches the cookbook’s core structure and the idea that Progress is a checkbox list with timestamps, plus decision/discovery logging. ([OpenAI Cookbook][2])

---

## 4. Add a structured “status contract” for automation

Create a schema file `ralph.schema.json`:

```json
{
  "type": "object",
  "properties": {
    "status": { "type": "string", "enum": ["IN_PROGRESS", "COMPLETE", "BLOCKED"] },
    "did": { "type": "string" },
    "commit_sha": { "type": ["string", "null"] },
    "next": { "type": ["string", "null"] },
    "notes": { "type": "string" }
  },
  "required": ["status", "did", "commit_sha", "next", "notes"],
  "additionalProperties": false
}
```

Codex can enforce that the **final message conforms to a JSON Schema** via `--output-schema`. ([OpenAI Developers][1])

Also add an output dir and gitignore it:

```bash
mkdir -p .ralph
echo ".ralph/" >> .gitignore
```

---

## 5. Create `afk-ralph.sh` (loop until Progress is complete)

This is your unattended runner.

```bash
#!/usr/bin/env bash
set -euo pipefail

iters="${1:-}"
if [[ -z "$iters" ]]; then
  iters="forever"
  echo "No iteration cap set; will run until Progress is complete or BLOCKED."
fi

progress_remaining() {
  awk '
    /^##[[:space:]]+Progress/ { in_progress=1; next }
    /^##[[:space:]]+/ { if (in_progress) exit }
    {
      if (in_progress && $0 ~ /^- \[ \]/) count++
    }
    END { print count + 0 }
  ' EXECPLAN.md
}

for ((i=1; ; i++)); do
  if [[ "$iters" == "forever" ]]; then
    echo "=== Ralph iteration $i ==="
  else
    echo "=== Ralph iteration $i/$iters ==="
  fi

  # For AFK runs, avoid hangs: never prompt for approvals.
  codex exec \
    --model gpt-5.2-codex \
    --sandbox danger-full-access \
    -c 'approval_policy="never"' \
    --output-schema ./ralph.schema.json \
    -o ./.ralph/last.json \
    - <<'PROMPT'
Ralph loop iteration.

Read .agent/PLANS.md and EXECPLAN.md.
Do exactly ONE unchecked Progress item (or split and do the first slice).
Implement, validate, commit once, update EXECPLAN.md.

Return ONLY JSON matching the output schema:
- status = COMPLETE if Progress is fully done.
- status = BLOCKED if you cannot proceed without human input.
PROMPT

  status="$(jq -r .status ./.ralph/last.json)"
  echo "status=$status"

  remaining="$(progress_remaining)"
  if [[ "$remaining" -eq 0 ]]; then
    echo "Progress complete after $i iterations."
    exit 0
  fi

  if [[ "$status" == "COMPLETE" && "$remaining" -gt 0 ]]; then
    echo "Agent reported COMPLETE but Progress has $remaining open item(s). Continuing."
  fi

  if [[ "$status" == "BLOCKED" ]]; then
    echo "Blocked on iteration $i. See ./.ralph/last.json"
    exit 2
  fi

  if [[ "$iters" != "forever" && "$i" -ge "$iters" ]]; then
    break
  fi
done

if [[ "$iters" == "forever" ]]; then
  echo "Stopped (unexpected exit without COMPLETE/BLOCKED)."
else
  echo "Stopped after $iters iterations (cap reached)."
fi
```

Make it executable:

```bash
chmod +x afk-ralph.sh
```

Run a single iteration:

```bash
./afk-ralph.sh 1
```

Or omit the cap and run until Progress is complete:

```bash
./afk-ralph.sh
```

Why the cap exists: without it, “agent loop” + “no approvals” is how you get surprise bills and a trashed branch. (That’s not a moral warning; it’s just how automation behaves.)

---

## 6. Reality check: where Ralph loops actually fail

If your plan is vague, Codex will “do work” that isn’t converging. ExecPlans are heavy for a reason: they force you to define **validation**, **concrete steps**, and a **clear end state**. ([OpenAI Cookbook][2])

Typical failure modes:

* Progress items aren’t atomic → you get half-finished mega-commits or constant “I had to refactor first…”
* No fast validation command → the agent can’t cheaply prove it didn’t break things (so it guesses)
* “Update progress.txt” split-brain → ExecPlan already has Progress; keep one source of truth

---

## 7. Make it your own (Codex-native variants)

A few Codex-specific upgrades:

* **Use structured outputs everywhere**: treat `--output-schema` as your “completion sigil,” not string matching. ([OpenAI Developers][1])
* **Resume instead of stateless** (optional): Codex can resume a non-interactive session: `codex exec resume --last "<follow-up>"`. ([OpenAI Developers][1])

  * This reduces re-reading cost, but increases “context drift.” Your ExecPlan should still be sufficient to restart anyway (that’s the whole point of ExecPlans). ([OpenAI Cookbook][2])
* **CI auth**: for `codex exec`, you can pass credentials via `CODEX_API_KEY` in CI. ([OpenAI Developers][1])
* **Model choice**: if you want cheaper iterations, swap to a smaller Codex model with `--model`. ([OpenAI Developers][6])

---
