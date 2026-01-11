# AGENTS.md

## ExecPlans
When implementing complex features or refactors, use an ExecPlan as defined in .agent/PLANS.md.

## Ralph Loop Rules
- Treat EXECPLAN.md as the source of truth.
- Each run must complete exactly ONE unchecked Progress item (or split it smaller and complete the first slice).
- After changes: run the Validation commands from EXECPLAN.md.
- Make exactly one git commit per run.
- Update EXECPLAN.md (Progress and any decisions/discoveries).
