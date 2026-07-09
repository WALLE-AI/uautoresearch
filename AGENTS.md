# Agent Instructions for uautoresearch

You are operating in a Markdown-driven **multi-agent** autonomous research framework. **Before doing anything else in this repo, read `SKILL.md` at the repo root.** It is the Orchestrator's routing table: it tells you which phase you are in and which sub-agent role to assume next.

This repo does not have a custom Python orchestrator process. All "who am I / what do I do" knowledge lives in two layers of Markdown:

- **`AGENT.md`** files (repo root + one per module: `scenarios/`, `datasets/`, `models/`, `planning/`, `trainer/`, `benchmark/`, `knowledge/`, `monitor/`) — define a **role**: identity, inputs, outputs, editable/read-only boundary, and hand-off/termination condition. Read the `AGENT.md` for the role you are about to assume *before* doing its work.
- **`SKILL.md`** files (root, `skills/<phase>/SKILL.md`, `<module>/SKILL.md`) — define **how** to do the work once you've assumed a role. Treat each as an instruction set you must actually open and follow — do not guess its contents from the filename.

## Roles (sub-agents)

There is one **Orchestrator** (whichever session/engine is currently driving) and 8 specialist roles it delegates to. Only one role is "worn" at a time within a single-agent execution engine (Windsurf/Cascade); engines that support true parallel sub-agents (see `engines/`) may run several simultaneously where the role boundaries allow it (e.g. multiple Trainer instances for independent candidates, or a Monitor Agent running concurrently with the Trainer Agent it watches).

There is no dedicated git-operations role: candidates are versioned as independent config files, not git commits, so no role owns commit/reset/branch state (see `experiment_logs/SKILL.md`).

| # | Role | Role card | Phase(s) |
|---|---|---|---|
| — | **Orchestrator** | `AGENT.md` (this file's companion) | all — routes, never edits training code itself |
| 1 | Scenario-Analysis Agent | `scenarios/AGENT.md` | Phase 1 |
| 2 | Dataset-Analysis Agent | `datasets/AGENT.md` | Phase 1, Phase 3 fallback |
| 3 | Model-Selection Agent | `models/AGENT.md` | Phase 1, Phase 2 |
| 4 | Training-Plan Agent | `planning/AGENT.md` | Planning (Phase 1 → 2 hand-off), and re-planning after Phase 3 |
| 5 | Trainer Agent | `trainer/AGENT.md` | Phase 3 |
| 6 | Monitor Agent | `monitor/AGENT.md` | Phase 3 (concurrent with Trainer Agent) |
| 7 | Evaluator Agent | `benchmark/AGENT.md` | Phase 1, Phase 3 (also owns keep/discard + the results ledger) |
| 8 | Knowledge-Update Agent | `knowledge/AGENT.md` | Phase 4 |

See `engines/windsurf.md`, `engines/cursor.md`, `engines/codex.md`, `engines/opencode.md` for how to declare these 8 roles as native sub-agents/rules/workflows in each execution engine.

## Minimal workflow

1. Read `/SKILL.md` (Orchestrator router) to determine the current phase.
2. Read the matching `skills/<phase>/SKILL.md` (scenario-analysis / `planning/SKILL.md` / experiment-design / experiment-loop / knowledge-update). It tells you which role(s) to assume and in what order.
3. Before doing a role's work, read that role's `AGENT.md` (identity/boundary/hand-off), then its `SKILL.md` (concrete steps).
4. Some module skills point to further `references/*.md` files (e.g. `trainer/references/<engine>.md`) — only read the one relevant to the current scenario, not all of them.
5. Execute the steps directly: edit config files, run shell commands, write logs — do not ask the human to do these for you unless a skill explicitly says to pause for confirmation.
6. When a role finishes, check its `AGENT.md` hand-off condition and explicitly state which role/phase comes next (this is the Orchestrator's job even when you are a single agent switching hats).

## Autonomy rules

- During Phase 3 (`skills/experiment-loop/SKILL.md`), keep iterating (Trainer → Monitor → Evaluator, repeat) without stopping to ask "should I continue?" until the time budget is exhausted, the target metric is reached, or the human interrupts you.
- Never edit files marked read-only in `trainer/SKILL.md` / `trainer/references/<engine>.md` (data loading, evaluation harness) — this boundary applies regardless of which role is currently active.
- **No git automation.** Every candidate is its own independent config file (never edited in place) — the Trainer Agent writes it, the Evaluator Agent decides keep/discard and records the result. "Discard" simply means that config file is not adopted as `current_best`; there is nothing to revert. Never overwrite a previous candidate's config file.
- When Phase 3's budget is exhausted, the Orchestrator must hand off to the Knowledge-Update Agent (Phase 4) — do not silently stop. If the target metric was not reached, also route back to the Training-Plan Agent for re-planning afterward (see root `AGENT.md`).

## Repo layout quick reference

```
AGENT.md               # Orchestrator role card
SKILL.md               # Orchestrator routing table — start here
skills/                # phase orchestration (scenario-analysis, experiment-design, experiment-loop, knowledge-update)
scenarios/             # scenario.yaml, analysis_report.md, training_plan.md, improve_guide.md, final_report.md per run
datasets/, models/, planning/, benchmark/, trainer/, scripts/, knowledge/
                        # each has README.md (what it is) + AGENT.md (who does it) + SKILL.md (how to use it)
experiment_logs/        # run.log/monitor.log/metrics.csv/experiment_results.csv format convention (no dedicated agent — see experiment_logs/SKILL.md)
engines/                # per-execution-engine adapter templates (windsurf, cursor, codex, opencode)
opensource/autoresearch/  # reference implementation only, do not copy its code directly
opensource/skills/        # Anthropic's official Agent Skills spec/examples, used as the format reference for this repo's SKILL.md files
```
