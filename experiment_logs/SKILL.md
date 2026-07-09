---
name: experiment-logging
description: Define and apply the unified run.log field format and the experiment_results.csv/results ledger format used across every domain and trainer engine. This is a shared format convention, not an agent role — the Trainer Agent writes run.log, the Monitor Agent writes monitor.log/metrics.csv, and the Evaluator Agent writes experiment_results.csv (see benchmark/AGENT.md). Use this whenever the experiment loop needs to extract a metric from a finished run, or whenever it needs to record a keep/discard/crash result.
---

# Experiment Logging

Keeps every experiment — regardless of domain or trainer engine — comparable and greppable, mirroring the `results.tsv` convention from `opensource/autoresearch`. There is no dedicated agent role for this module — it is a shared format convention. Candidates are versioned as independent config files (see `trainer/AGENT.md`), not git commits, so this ledger has no `commit` column and there is no git-based revert step anywhere in the framework.

## `run.log` location

Every training run's `run.log` lives at `experiment_logs/<tag>/runs/<candidate>/run.log` — **not** inside the trainer engine's own checkpoint/output directory (`RUN_DIR`), which stays wherever the engine writes weights/artifacts. This keeps every log centralized under `experiment_logs/` regardless of domain or engine, and is where the Monitor Agent (`monitor/SKILL.md`) also writes its `monitor.log`/`metrics.csv` for the same candidate:

```
experiment_logs/<tag>/runs/<candidate>/
    run.log        # Trainer Agent / engine wrapper output (this section's fields)
    monitor.log    # Monitor Agent's polling record + [ALERT] lines (Phase 3 only)
    metrics.csv    # Monitor Agent's time-series snapshots (Phase 3 only)
```

## `run.log` fields

Every trainer engine wrapper (see `trainer/SKILL.md`, `scripts/SKILL.md`) must ensure these fields appear as `key: value` lines somewhere in `run.log`, so they can be extracted with a simple grep:

```
metric_name:      <string>
metric_value:     <float>
training_seconds: <float>
total_seconds:    <float>
peak_vram_mb:     <float>
num_params_M:     <float>
```

Extract with:

```bash
grep "^metric_value:\|^peak_vram_mb:" run.log
```

If this grep returns empty, the run crashed — see `skills/experiment-loop/SKILL.md` step 6 for what to do next (tail the log, decide fix-and-retry vs. record-crash-and-move-on).

See `references/log-schema.md` for the full field reference, including optional domain-specific extra fields.

## `experiment_results.csv` (per scenario, at `experiment_logs/<tag>/experiment_results.csv`)

Tab or comma-separated (pick one and stay consistent within a scenario — tab is safer if descriptions might contain commas), with header:

```
candidate,config_path,metric_value,peak_vram_gb,status,domain,engine,description
```

- `candidate` — short candidate name (e.g. `lr-0.01`, `cosine-sched`).
- `config_path` — path to this candidate's independent config file (see `trainer/AGENT.md`'s config-file-lineage rule) — this is what replaces a git commit hash for provenance.
- `metric_value` — the achieved metric; use `0.0`/`0` for crashes.
- `peak_vram_gb` — peak_vram_mb / 1024, rounded to 1 decimal; `0.0` for crashes.
- `status` — one of `keep`, `discard`, `crash`.
- `domain` — from `scenario.yaml`.
- `engine` — `trainer_engine` from `scenario.yaml`.
- `description` — short human-readable description of what this experiment tried.

Example:

```
candidate,config_path,metric_value,peak_vram_gb,status,domain,engine,description
baseline,scenarios/cv-detect-aug12/configs/baseline.yaml,0.8120,12.3,keep,cv,ultralytics,baseline
lr-0.01,scenarios/cv-detect-aug12/configs/lr-0.01.yaml,0.8340,12.4,keep,cv,ultralytics,increase LR to 0.01
cosine-sched,scenarios/cv-detect-aug12/configs/cosine-sched.yaml,0.8050,12.3,discard,cv,ultralytics,switch to cosine schedule
batch-double,scenarios/cv-detect-aug12/configs/batch-double.yaml,0.0,0.0,crash,cv,ultralytics,double batch size (OOM)
```

This file is a local progress ledger, not reviewable code — it is fine to leave it out of version control (`.gitignore`) if the repo is git-tracked, same as `opensource/autoresearch`'s `results.tsv` convention, though this is now just a housekeeping preference, not a hard requirement of the framework's operation.

## Responsibilities

- The **Evaluator Agent** (`benchmark/AGENT.md`) appends one row per completed experiment, in order, as the loop runs — do not batch writes at the end (if the loop is interrupted, partial results should still be on disk).
- Never rewrite or delete previous rows.
- When a scenario finishes, this file is a key input to `skills/knowledge-update/SKILL.md` and to `scenarios/<tag>/final_report.md`.

## Notes

- If a new domain needs an extra log field beyond the six universal ones, add it to `references/log-schema.md` rather than overloading an existing field's meaning.
