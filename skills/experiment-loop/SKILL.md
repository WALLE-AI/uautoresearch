---
name: experiment-loop
description: Phase 3 orchestration skill for uautoresearch, the core autonomous experimentation loop. Use once `improve_guide.md` exists and it's time to actually run experiments — tweak a config or training file, run a single fixed-time-budget training job, compare the metric to the current best, keep or discard the change, log the result, and repeat without stopping. This is the "let it run overnight" skill; use it whenever the user wants unattended, autonomous hyperparameter/architecture search.
---

# Phase 3: Automated Experiment Loop

This skill generalizes the loop from `opensource/autoresearch/program.md` (single-file GPT training) to any domain and trainer engine. The mechanics are the same: fixed time budget, one variable at a time, keep/discard/crash, log everything, never stop on your own.

## Prerequisites

- `scenarios/<tag>/scenario.yaml` (domain, `trainer_engine`, `time_budget_min`, `metric`, baseline value)
- `scenarios/<tag>/improve_guide.md` (ordered list of candidates to try)
- A dedicated git branch for this run, e.g. `autoresearch/<tag>`. Create it from the current branch if it doesn't exist yet.

## Read-only vs. editable boundaries

Before starting, read `trainer/SKILL.md` and the relevant `trainer/references/<engine>.md` file for `trainer_engine`. It tells you exactly which files you may edit (training config, hyperparameters, and — if the engine allows — model code) and which are strictly read-only (data loading, the evaluation harness, the metric computation). **Never edit the read-only files.** If an experiment idea requires changing a read-only file, it is out of scope for this loop — note it and move on.

## The loop

```
LOOP FOREVER (until time budget for the scenario is exhausted or the human interrupts):

1. Check current git state (branch, last commit, current best metric).
2. Pick the next candidate from improve_guide.md:
   - Single-variable exploration first (one change at a time).
   - Once individual wins are validated, try orthogonal combinations.
   - If both plateau, fall back to the data-dimension plan in improve_guide.md
     (delegate data changes to datasets/SKILL.md).
3. Make the change (edit only the editable files per trainer/SKILL.md).
4. git commit the change with a short, descriptive message.
5. Launch the run via scripts/SKILL.md, using the engine wrapper convention:
   scripts/<engine>_run.sh <config> <time_budget_min>
   Redirect all output to run.log. Do not let output flood your context —
   read it back with targeted greps, not by dumping the whole file.
6. Extract the metric from run.log per the fields defined in
   experiment_logs/SKILL.md (grep the metric_name/metric_value lines).
   - If the grep output is empty, the run crashed: tail the last ~50 lines
     of run.log to find the error. If it's something dumb and quick to fix
     (typo, missing import, wrong path), fix it and retry once. If the idea
     itself is fundamentally broken, record status=crash and move on.
7. Compare the metric to the current best (respecting metric.direction from
   scenario.yaml — minimize or maximize).
   - Improved -> status=keep. This becomes the new best; the branch advances
     on this commit.
   - Equal or worse -> status=discard. git reset back to the commit before
     this change.
8. Append the result to experiment_logs/<tag>/experiment_results.csv via
   experiment_logs/SKILL.md (do not track this file in git).
9. Go to step 1.
```

## Hard constraints

- **Fixed time budget.** Every run uses the same `time_budget_min` from `scenario.yaml`, regardless of what changed. If a run exceeds ~2x the budget, kill it, treat it as a failure, discard, and revert.
- **Simplicity criterion.** All else equal, simpler is better. A tiny metric improvement that adds a lot of hacky complexity is usually not worth keeping — use judgment, but lean towards simplicity. Removing code while keeping the metric flat or better is a good outcome (a "simplification win"), not something to discard.
- **VRAM is a soft constraint.** Some increase is fine for a meaningful metric gain; don't let it blow up dramatically without a clear payoff.
- **Never stop to ask "should I keep going?"** Once this loop starts, continue autonomously until the budget is exhausted or the human explicitly interrupts. The user may be asleep or away and expects to come back to a finished log of experiments.
- **If you run out of ideas**, don't stop — go back to `knowledge/SKILL.md` for more candidates, re-read `improve_guide.md` for angles not yet tried, or combine two previously-near-miss changes.

## Handoff

When the loop ends (budget exhausted or interrupted), summarize the run (best result, number of experiments, keep/discard/crash counts) and hand off to `skills/knowledge-update/SKILL.md` to fold the findings back into the experience base.
