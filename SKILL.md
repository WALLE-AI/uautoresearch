---
name: uautoresearch
description: Root entry point and phase router for the uautoresearch autonomous multi-domain training research framework. Use this skill whenever the user gives a research goal, a dataset sample, and a compute/time budget and wants to autonomously analyze a scenario, design an experiment plan, or run an automated CV/NLP/LLM/VLM training experiment loop. Also use it when the user says things like "kick off a new research run", "train this model automatically", "find the best hyperparameters overnight", or references `program.md`-style autonomous research. This skill only routes to the phase skills below — it does not itself perform analysis, training, or logging.
---

# uautoresearch

`uautoresearch` is a Markdown-driven multi-agent framework that autonomously runs the full research loop — scenario understanding, experiment design, automated experimentation, and knowledge accumulation — across CV, NLP, LLM, and VLM training. It generalizes the "agent edits code, runs a fixed time budget, checks the metric, keeps or discards, repeats" idea from `opensource/autoresearch/program.md` to any domain and any pluggable training engine.

## How to use this entry point

Do not try to do the work described below yourself from memory. Read the referenced skill file for the phase you are in, follow its instructions exactly, and let it tell you which module skills to consult next.

```
[User input] research goal + data sample + budget
    │
    ▼
[Phase 1] Scenario understanding & baseline analysis
    → read skills/scenario-analysis/SKILL.md
    │
    ▼
[Phase 2] Experiment plan design
    → read skills/experiment-design/SKILL.md
    │
    ▼
[Phase 3] Automated experiment loop (the core, runs "forever" until budget/interrupt)
    → read skills/experiment-loop/SKILL.md
    │
    ▼
[Phase 4] Knowledge accumulation
    → read skills/knowledge-update/SKILL.md
```

## Routing rules

1. **New research request** (goal + data + budget, no existing `scenarios/<tag>/scenario.yaml`): start at Phase 1.
2. **`scenario.yaml` and `analysis_report.md` already exist, no `improve_guide.md` yet**: start at Phase 2.
3. **`improve_guide.md` exists, no experiment loop running yet, or the user wants to resume/continue experimentation**: start at Phase 3.
4. **A `scenarios/<tag>/` run just finished (budget exhausted or user stopped it) and results have not been folded back into `knowledge/`**: run Phase 4.
5. If the user's request only concerns one specific module (e.g. "just tell me what training engine to use" or "update the dataset README"), skip straight to that module's `SKILL.md` (see table below) instead of going through the phase pipeline.

## Module skills (capability layer)

Each phase skill calls into these module skills to do concrete work. Each module directory keeps a `README.md` (human-facing "what this is") alongside its `SKILL.md` (agent-facing "how to do it").

| Module | Skill file | Responsibility |
|---|---|---|
| `scenarios/` | `scenarios/SKILL.md` | Scenario record management: `scenario.yaml`, `analysis_report.md`, `improve_guide.md` |
| `datasets/` | `datasets/SKILL.md` | Dataset EDA and dataset construction/synthesis |
| `models/` | `models/SKILL.md` | Base model / architecture selection per scenario |
| `benchmark/` | `benchmark/SKILL.md` | Evaluation benchmark selection and execution |
| `trainer/` | `trainer/SKILL.md` | Pluggable training engine adapters (LLM/VLM/CV/NLP) |
| `scripts/` | `scripts/SKILL.md` | Engine launch script generation and invocation |
| `experiment_logs/` | `experiment_logs/SKILL.md` | Run logging format and results ledger |
| `knowledge/` | `knowledge/SKILL.md` | Experience retrieval and write-back |

## Core principles (do not violate these)

- **Fixed time budget, comparable runs.** Every experiment in the loop runs for the same configured wall-clock window (`time_budget_min` in `scenario.yaml`), regardless of domain. This is what makes experiments comparable and is what makes overnight unattended runs possible.
- **keep / discard / crash.** After every run, compare the metric to the current best. Keep improvements, discard regressions (git reset), record crashes and move on. Never leave the repo in a broken, uncommitted state between iterations.
- **Read-only vs editable boundaries.** Each trainer engine defines which files the agent may edit (config/hyperparameters) and which are off-limits (data loading, evaluation harness). Never edit the read-only files — see `trainer/SKILL.md`.
- **Autonomy during the loop.** Once Phase 3 starts, do not stop to ask "should I keep going?". Keep iterating until the budget is exhausted or the human interrupts. This is the entire point of the framework — the human should be able to walk away.
- **Everything is Markdown, not Python.** Humans maintain skill files; the agent reads them and does the work directly (editing configs, running commands, writing logs). Do not build a custom Python orchestrator on top of this.