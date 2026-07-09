# Engine adapter: Cursor

Cursor supports project rules via `.cursor/rules/*.mdc` (scoped by glob/always-on/agent-requested) and Cursor Agent mode for autonomous multi-step execution. This adapter maps the 8 `uautoresearch` roles to `.mdc` rule files that Cursor's agent loads based on which part of the repo it's touching. There is no Git-Ops role — the Evaluator Agent owns keep/discard and the results ledger via independent config files, not git commits.

## Mapping

| uautoresearch concept | Cursor construct |
|---|---|
| Orchestrator | An always-on rule (`.cursor/rules/000-orchestrator.mdc`) pointing to `AGENTS.md`/`SKILL.md`, loaded in every agent session. |
| Each of the 8 specialist roles | One `.cursor/rules/<role>.mdc` file, scoped via `globs:` to the directories that role owns (e.g. the Trainer Agent rule globs `trainer/**`, `scripts/**`), so Cursor auto-attaches the role's `AGENT.md` content whenever the agent edits files in that role's territory. |
| Phase 3 parallel mode | Cursor's background agent / multiple parallel Composer tabs, each given the Trainer Agent rule + one candidate's own new config file — coordinate keep/discard afterward in a single Evaluator-rule session, per `skills/experiment-loop/SKILL.md`. |

## Setup

1. `.cursor/rules/000-orchestrator.mdc`:
   ```markdown
   ---
   description: uautoresearch orchestrator — always active
   alwaysApply: true
   ---
   Read AGENTS.md and SKILL.md at the repo root before any research/training
   task. Route to the correct phase and specialist role per their contents.
   ```
2. One rule per role, e.g. `.cursor/rules/trainer-agent.mdc`:
   ```markdown
   ---
   description: Trainer Agent role — training config/launch boundary
   globs: ["trainer/**", "scripts/**", "scenarios/*/configs/**"]
   ---
   You are the Trainer Agent (see trainer/AGENT.md). Read trainer/SKILL.md and
   the matching trainer/references/<engine>.md before editing any file under
   these globs. Never edit data-loading or evaluation-harness code.
   ```
   Repeat analogously for `scenario-analysis-agent.mdc` (`globs: ["scenarios/**"]`), `dataset-analysis-agent.mdc` (`globs: ["datasets/**"]`), `model-selection-agent.mdc` (`globs: ["models/**"]`), `training-plan-agent.mdc` (`globs: ["planning/**", "scenarios/*/training_plan.md"]`), `monitor-agent.mdc` (`globs: ["monitor/**", "experiment_logs/*/runs/**"]`, read-only tools only), `evaluator-agent.mdc` (`globs: ["benchmark/**", "experiment_logs/**", "scenarios/*/scenario.yaml"]`), `knowledge-update-agent.mdc` (`globs: ["knowledge/**"]`).
3. For parallel Phase 3 runs, launch one Composer/background-agent instance per candidate with the Trainer Agent rule active and the candidate's own new config file pre-selected; run final keep/discard bookkeeping in one Evaluator-rule session after all finish (mirrors `scripts/loop_driver_template.sh`).

## Notes

- Glob-scoped rules mean Cursor will auto-attach the right role context by file path — keep each role's edits within its own globs so the wrong role's context doesn't silently apply.
- `alwaysApply: true` should be reserved for the orchestrator rule only; specialist role rules should stay glob- or agent-requested-scoped to avoid context bloat.
