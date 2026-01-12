# AGENTS.md
<!-- Repo-level Codex behavior rules for running Ralph against external repos. -->

## Plan Authoring Mode (External Projects)
If the user is requesting an ExecPlan for an external project, ignore the Ralph Loop Rules below. In this mode:
- Ask for the target repo path if it is not provided in the config at ralph.config.toml
- Read the target repo files to understand structure, build/test workflows, and constraints.
- Write or update the external plan at `.agent/execplans/execplan.md` in the target repo.
- Follow the target repo's `.agent/PLANS.md`.
- If `.agent/PLANS.md` is missing, ask the user to run `./init-project.sh <path>`.
- Do not run validation commands or make git commits.
- Ensure the plan notes it is maintained according to `.agent/PLANS.md`.

## ExecPlans
When implementing complex features or refactors, use an ExecPlan as defined in the target repo's .agent/PLANS.md.

## Ralph Loop Rules
- Treat `.agent/execplans/execplan.md` as the source of truth.
- Each run must complete exactly ONE unchecked Progress item (or split it smaller and complete the first slice).
- After changes: run the Validation commands from `.agent/execplans/execplan.md`.
- Make exactly one git commit per run.
- Update `.agent/execplans/execplan.md` (Progress and any decisions/discoveries).
