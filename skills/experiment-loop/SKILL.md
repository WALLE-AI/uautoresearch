---
name: experiment-loop
description: Phase 3 orchestration skill for uautoresearch, the core autonomous experimentation loop. Use once `improve_guide.md` exists and it's time to actually run experiments — write a new candidate config, run a single fixed-time-budget training job, compare the metric to the current best, keep or discard the change, check it against the target metric, log the result, and repeat without stopping. This is the "let it run overnight" skill; use it whenever the user wants unattended, autonomous hyperparameter/architecture search.
---

# Phase 3: Automated Experiment Loop

This skill generalizes the loop from `opensource/autoresearch/program.md` (single-file GPT training) to any domain and trainer engine. The mechanics are the same: fixed time budget, one variable at a time, keep/discard/crash, log everything, never stop on your own — but versioning is by **independent config file**, not git commit (see `trainer/AGENT.md`'s config-file-lineage rule). There is no Git-Ops role in this framework.

## Prerequisites

- `scenarios/<tag>/scenario.yaml` (domain, `trainer_engine`, `time_budget_min`, `metric` incl. `target`, `baseline`, `current_best`)
- `scenarios/<tag>/improve_guide.md` (ordered list of candidates to try)
- `scenarios/<tag>/configs/` containing the baseline (and, once the loop has run before, current-best) config file that new candidates are copied from

## Roles in this loop

This loop is executed by specialist roles handing off to each other, not one undifferentiated "the agent". Read each role's `AGENT.md` before acting as it:

- **Trainer Agent** (`trainer/AGENT.md`) — writes each candidate's own config file, launches the run(s).
- **Monitor Agent** (`monitor/AGENT.md`) — polls each run *while it is in progress* for loss/metric/GPU health, runs concurrently with the Trainer Agent's wait, never blocks it.
- **Evaluator Agent** (`benchmark/AGENT.md`) — extracts/interprets the final metric, detects crashes, decides keep/discard, checks the `PASS`/`FAIL` target-metric gate, updates `current_best`, and appends to the results ledger. This absorbs everything the old Git-Ops role used to do, minus the git operations (there are none).

All run logs (`run.log`, and the Monitor Agent's `monitor.log`/`metrics.csv`) live together under `experiment_logs/<tag>/runs/<candidate>/` — see `experiment_logs/SKILL.md`.

## Read-only vs. editable boundaries

Before starting, the Trainer Agent reads `trainer/SKILL.md` and the relevant `trainer/references/<engine>.md` file for `trainer_engine`. It tells you exactly which files you may edit (training config, hyperparameters, and — if the engine allows — model code) and which are strictly read-only (data loading, the evaluation harness, the metric computation). **Never edit the read-only files.** If an experiment idea requires changing a read-only file, it is out of scope for this loop — note it and move on.

## The loop (sequential mode — default)

```
LOOP FOREVER (until time budget for the scenario is exhausted, PASS is
reached, or the human interrupts):

1. [Orchestrator] Read scenario.yaml's current_best and status; confirm not
   already target_met/done.
2. [Trainer, with candidates from Model-Selection/Dataset-Analysis Agents]
   Pick the next candidate from improve_guide.md:
   - Single-variable exploration first (one change at a time).
   - Once individual wins are validated, try orthogonal combinations.
   - If both plateau, fall back to the data-dimension plan in improve_guide.md
     (delegate data changes to the Dataset-Analysis Agent, datasets/SKILL.md).
3. [Trainer] Copy scenario.yaml's current_best.config_path to a NEW file
   scenarios/<tag>/configs/<candidate>.<ext> and edit only that copy (only
   the editable fields per trainer/AGENT.md). Never edit the current-best
   config file in place — this is what makes discard free and keep trivial.
4. [Trainer] Launch the run via scripts/SKILL.md, using the engine wrapper
   convention: scripts/<engine>_run.sh <config> <time_budget_min>
   Output goes to experiment_logs/<tag>/runs/<candidate>/run.log. Do not let
   output flood your context — read it back with targeted greps, not by
   dumping the whole file.
4b. [Monitor] Start polling this run concurrently (monitor/SKILL.md) —
   writes experiment_logs/<tag>/runs/<candidate>/{monitor.log,metrics.csv}.
   Runs independently of the Trainer Agent's wait; surfaces [ALERT] lines
   for nan/inf loss or a suspected hang, but never kills the process itself.
5. [Evaluator] Extract the metric from run.log per the fields defined in
   experiment_logs/SKILL.md (grep the metric_name/metric_value lines).
   - If the grep output is empty, the run crashed: tail the last ~50 lines
     of run.log to find the error. If it's something dumb and quick to fix
     (typo, missing import, wrong path), hand back to Trainer to fix and
     retry once (still on the same candidate config file). If the idea
     itself is fundamentally broken, report status=crash and move on.
6. [Evaluator] Compare the metric to current_best (respecting
   metric.direction from scenario.yaml — minimize or maximize).
   - Improved -> status=keep. Update scenario.yaml's current_best to
     {value, config_path: this candidate's file, candidate: <name>}.
   - Equal or worse -> status=discard. Do nothing to current_best — the
     candidate's config file simply is not referenced by it. No revert.
7. [Evaluator] If scenario.yaml's metric.target is set, check the (possibly
   just-updated) current_best value against it -> PASS or FAIL.
8. [Evaluator] Append the result to experiment_logs/<tag>/experiment_results.csv
   via experiment_logs/SKILL.md (candidate, config_path, metric_value, ...).
9. [Evaluator -> Orchestrator] If PASS: stop the loop, set scenario.yaml
   status: target_met, hand off to Phase 4 (skills/knowledge-update/SKILL.md).
   If FAIL and budget remains: go to step 1. If FAIL and budget is exhausted:
   stop the loop and hand off to Phase 4 as in Handoff below.
```

## Parallel mode (multi-GPU, independent single-variable candidates)

When two or more candidates from `improve_guide.md` are mutually independent (same baseline, no shared state) and the host has multiple idle GPUs, the Trainer Agent may launch them concurrently instead of one at a time — this is the pattern validated in practice on an 8×A100 host (`cv-svrdd-detect-jul06`). The mechanics differ from sequential mode only in steps 3-8:

```
1. [Orchestrator] Read scenario.yaml's current_best and status.
2. [Trainer] Select N mutually-independent candidates from improve_guide.md
   (same tier, same baseline, no shared config/state).
3. [Trainer] Copy current_best.config_path to N separate NEW config files,
   one per candidate (scenarios/<tag>/configs/<candidate_i>.<ext>) — never
   one shared file, never edit the current-best file itself.
4. [Trainer] Launch all N runs concurrently, one per idle GPU, each writing
   its own run.log under experiment_logs/<tag>/runs/<candidate>/.
4b. [Monitor] Start one poller per candidate concurrently (monitor/SKILL.md),
   writing monitor.log/metrics.csv alongside each run.log. Pollers run
   independently of the Trainer Agent's wait and of each other.
5. [Trainer] Wait for all N runs to finish (or be killed at ~2x budget).
6. [Evaluator] Extract the metric from each run's run.log (crash detection
   per run, same as sequential mode).
7. [Evaluator] For EACH candidate independently, in the order they finished:
   - Improved over the current_best at the time -> status=keep, current_best
     updates to point at that candidate's own config file.
   - Equal or worse -> status=discard — nothing to revert, its config file
     is simply never referenced by current_best.
   - Check metric.target against the (possibly updated) current_best after
     each candidate is processed -> PASS/FAIL.
8. [Evaluator] Append one experiment_results.csv row per candidate (not one
   row for the whole batch).
9. [Evaluator -> Orchestrator] Same PASS/FAIL/budget handling as sequential
   mode step 9.
```

`scripts/loop_driver_template.sh` implements this parallel pattern generically (per-candidate config file + per-candidate keep/discard, no git) — prefer adapting it over hand-rolling a new driver script per scenario.

## Hard constraints

- **Fixed time budget.** Every run uses the same `time_budget_min` from `scenario.yaml`, regardless of what changed. If a run exceeds ~2x the budget, kill it, treat it as a failure, discard (config file simply unused).
- **Simplicity criterion.** All else equal, simpler is better. A tiny metric improvement that adds a lot of hacky complexity is usually not worth keeping — use judgment, but lean towards simplicity. Removing complexity while keeping the metric flat or better is a good outcome (a "simplification win"), not something to discard.
- **VRAM is a soft constraint.** Some increase is fine for a meaningful metric gain; don't let it blow up dramatically without a clear payoff.
- **Never stop to ask "should I keep going?"** Once this loop starts, continue autonomously until the budget is exhausted, the target metric is reached (`PASS`), or the human explicitly interrupts. The user may be asleep or away and expects to come back to a finished log of experiments.
- **If you run out of ideas**, don't stop — go back to `knowledge/SKILL.md` for more candidates, re-read `improve_guide.md` for angles not yet tried, or combine two previously-near-miss changes.

## Handoff

When the loop ends, summarize the run (best result, number of experiments, keep/discard/crash counts, PASS/FAIL) and hand off to `skills/knowledge-update/SKILL.md` to fold the findings back into the experience base — **always**, whether it ended in `PASS` (target met) or budget exhaustion with `FAIL`. If it ended `FAIL`, the Orchestrator routes back to the Training-Plan Agent (`planning/AGENT.md`) for re-planning immediately after knowledge write-back finishes (see root `AGENT.md`'s hand-off rule) — the scenario is not `done` in that case, it goes around again.
