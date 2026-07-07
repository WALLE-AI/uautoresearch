---
name: experiment-logging
description: Define and apply the unified run.log field format and the experiment_results.csv/results ledger format used across every domain and trainer engine. Use this whenever the experiment loop needs to extract a metric from a finished run, or whenever it needs to record a keep/discard/crash result.
---

# Experiment Logging

Keeps every experiment — regardless of domain or trainer engine — comparable and greppable, mirroring the `results.tsv` convention from `opensource/autoresearch`.

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
commit,metric_value,peak_vram_gb,status,domain,engine,description
```

- `commit` — short git commit hash (7 chars) for the change tested.
- `metric_value` — the achieved metric; use `0.0`/`0` for crashes.
- `peak_vram_gb` — peak_vram_mb / 1024, rounded to 1 decimal; `0.0` for crashes.
- `status` — one of `keep`, `discard`, `crash`.
- `domain` — from `scenario.yaml`.
- `engine` — `trainer_engine` from `scenario.yaml`.
- `description` — short human-readable description of what this experiment tried.

Example:

```
commit,metric_value,peak_vram_gb,status,domain,engine,description
a1b2c3d,0.8120,12.3,keep,cv,ultralytics,baseline
b2c3d4e,0.8340,12.4,keep,cv,ultralytics,increase LR to 0.01
c3d4e5f,0.8050,12.3,discard,cv,ultralytics,switch to cosine schedule
d4e5f6g,0.0,0.0,crash,cv,ultralytics,double batch size (OOM)
```

**Do not track `experiment_results.csv` in git** — leave it untracked, per the same convention as `opensource/autoresearch`'s `results.tsv`. It is a local ledger of the loop's progress, not part of the reviewable code diff.

## Responsibilities

- Append one row per completed experiment, in order, as the loop runs — do not batch writes at the end (if the loop is interrupted, partial results should still be on disk).
- Never rewrite or delete previous rows.
- When a scenario finishes, this file is a key input to `skills/knowledge-update/SKILL.md` and to `scenarios/<tag>/final_report.md`.

## Notes

- If a new domain needs an extra log field beyond the six universal ones, add it to `references/log-schema.md` rather than overloading an existing field's meaning.
