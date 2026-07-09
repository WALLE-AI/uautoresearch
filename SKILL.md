---
name: uautoresearch
description: Root entry point and phase router for the uautoresearch autonomous multi-domain training research framework. Use this skill whenever the user gives a research goal, a dataset sample, and a compute/time budget and wants to autonomously analyze a scenario, design an experiment plan, or run an automated CV/NLP/LLM/VLM training experiment loop. Also use it when the user says things like "kick off a new research run", "train this model automatically", "find the best hyperparameters overnight", or references `program.md`-style autonomous research. This skill only routes to the phase skills below — it does not itself perform analysis, training, or logging.
---

# uautoresearch

`uautoresearch` is a Markdown-driven multi-agent framework that autonomously runs the full research loop — scenario understanding, experiment design, automated experimentation, and knowledge accumulation — across CV, NLP, LLM, and VLM training. It generalizes the "agent edits code, runs a fixed time budget, checks the metric, keeps or discards, repeats" idea from `opensource/autoresearch/program.md` to any domain and any pluggable training engine.

## How to use this entry point

Do not try to do the work described below yourself from memory. Read the referenced skill file for the phase you are in, follow its instructions exactly, and let it tell you which module skills to consult next.

```
[User input] research goal + data sample + budget + compute + target metric
    │
    ▼
[Phase 1] Scenario understanding & baseline analysis
    → read skills/scenario-analysis/SKILL.md
    │
    ▼
[Planning] Training plan generation (resource plan + training calendar)
    → read planning/SKILL.md
    │
    ▼
[Phase 2] Experiment plan design
    → read skills/experiment-design/SKILL.md
    │
    ▼
[Phase 3] Automated experiment loop (runs until budget exhausted OR target metric reached)
    → read skills/experiment-loop/SKILL.md
    │
    ├─ target reached ──────────────────────────┐
    │                                            ▼
    └─ budget exhausted, target NOT reached      [Phase 4] Knowledge accumulation
         │                                          → read skills/knowledge-update/SKILL.md
         ▼                                            │
       back to [Planning] for re-plan  ◄──────────────┘ (always runs first either way)
```

## Routing rules

1. **New research request** (goal + data + budget, no existing `scenarios/<tag>/scenario.yaml`): start at Phase 1.
2. **`scenario.yaml` and `analysis_report.md` already exist, no `training_plan.md` yet**: start at Planning (`planning/SKILL.md`).
3. **`training_plan.md` exists, no `improve_guide.md` yet**: start at Phase 2.
4. **`improve_guide.md` exists, no experiment loop running yet, or the user wants to resume/continue experimentation**: start at Phase 3.
5. **A `scenarios/<tag>/` run just finished (budget exhausted or target reached) and results have not been folded back into `knowledge/`**: run Phase 4.
6. **Phase 4 just finished and `scenario.yaml status` is not `done`** (budget was exhausted without reaching the target metric): route back to Planning for re-planning — do not treat the scenario as finished.
7. If the user's request only concerns one specific module (e.g. "just tell me what training engine to use" or "update the dataset README"), skip straight to that module's `SKILL.md` (see table below) instead of going through the phase pipeline.

## Module skills (capability layer) and their agent roles

Each phase skill calls into these module skills to do concrete work, "worn" as the specialist role listed below (see `AGENTS.md` for the full role table and `<module>/AGENT.md` for each role's identity/boundary/hand-off). Each module directory keeps a `README.md` (human-facing "what this is"), `AGENT.md` (agent-facing "who does this") and `SKILL.md` (agent-facing "how to do it").

| Module | Agent role | Skill file | Responsibility |
|---|---|---|---|
| `scenarios/` | Scenario-Analysis Agent | `scenarios/SKILL.md` | Scenario record management: `scenario.yaml`, `analysis_report.md`, `improve_guide.md` |
| `datasets/` | Dataset-Analysis Agent | `datasets/SKILL.md` | Dataset EDA and dataset construction/synthesis |
| `models/` | Model-Selection Agent | `models/SKILL.md` | Base model selection + network-architecture optimization per scenario |
| `planning/` | Training-Plan Agent | `planning/SKILL.md` | Resource plan + training calendar (`training_plan.md`), Phase 1→2 hand-off, re-planning after Phase 3 |
| `benchmark/` | Evaluator Agent | `benchmark/SKILL.md` | Evaluation benchmark selection/execution, PASS/FAIL judgment, keep/discard decision, results ledger |
| `trainer/` | Trainer Agent | `trainer/SKILL.md` | Pluggable training engine adapters (LLM/VLM/CV/NLP), per-candidate config files |
| `monitor/` | Monitor Agent | `monitor/SKILL.md` | In-progress run health polling (loss/metric/GPU) and basic anomaly alerts |
| `scripts/` | (Trainer Agent tooling) | `scripts/SKILL.md` | Engine launch script generation and invocation |
| `experiment_logs/` | (shared convention, no dedicated agent) | `experiment_logs/SKILL.md` | Run logging format and results-ledger format used by Trainer/Monitor/Evaluator |
| `knowledge/` | Knowledge-Update Agent | `knowledge/SKILL.md` | Experience retrieval and structured Knowledge Card write-back |

`scripts/` has no dedicated `AGENT.md` — it is tooling invoked by the Trainer Agent, not a separate role. `experiment_logs/` also has no dedicated `AGENT.md` — it is a shared logging/ledger format convention that the Trainer, Monitor, and Evaluator Agents all write into directly; there is no git-based version control step.

## Core principles (do not violate these)

- **Fixed time budget, comparable runs.** Every experiment in the loop runs for the same configured wall-clock window (`time_budget_min` in `scenario.yaml`), regardless of domain. This is what makes experiments comparable and is what makes overnight unattended runs possible.
- **keep / discard / crash, no git.** After every run, the Evaluator Agent compares the metric to the current best. Keep improvements (advance `scenario.yaml`'s `current_best` to point at that candidate's config file), discard regressions (simply don't adopt that config file — nothing to revert), record crashes and move on. Every candidate is its own independent config file, never edited in place, so there is no "uncommitted state" to worry about between iterations.
- **Read-only vs editable boundaries.** Each trainer engine defines which files the agent may edit (config/hyperparameters) and which are off-limits (data loading, evaluation harness). Never edit the read-only files — see `trainer/SKILL.md`.
- **Autonomy during the loop.** Once Phase 3 starts, do not stop to ask "should I keep going?". Keep iterating until the budget is exhausted, the target metric is reached, or the human interrupts. This is the entire point of the framework — the human should be able to walk away.
- **Everything is Markdown, not Python.** Humans maintain skill files; the agent reads them and does the work directly (editing configs, running commands, writing logs). Do not build a custom Python orchestrator on top of this.