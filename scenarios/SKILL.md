---
name: scenario-management
description: Manage the scenario record for a single research run — creating, reading, and updating `scenario.yaml`, `analysis_report.md`, `improve_guide.md`, and `final_report.md` under `scenarios/<tag>/`. Use this whenever any phase skill needs to read scenario metadata (domain, trainer engine, budget, metric) or persist scenario-level artifacts, or when the user asks about an existing scenario's status or history.
---

# Scenario Management

`scenarios/<tag>/` is the single source of truth for one research run: what domain/task it targets, which trainer engine and budget it uses, and what has been learned so far. Every phase skill reads and writes through this skill rather than inventing its own file layout.

## Directory layout per scenario

```
scenarios/<tag>/
├── scenario.yaml         # machine-readable scenario definition (see schema below)
├── analysis_report.md    # Phase 1 output
├── improve_guide.md      # Phase 2 output
└── final_report.md       # Phase 4 output (written once the loop for this tag ends)
```

`<tag>` should be short, date-based, and descriptive, e.g. `llm-sft-jul06`, `cv-detect-aug12`. Never reuse a tag for a different scenario — if resuming the same scenario, reuse the same tag; if starting fresh, propose a new one and confirm it doesn't already exist under `scenarios/`.

## `scenario.yaml` schema

```yaml
tag: <run-tag>
domain: cv | nlp | llm | vlm
task_type: <string>              # e.g. object-detection, instruction-sft, text-classification
base_model: <string>
trainer_engine: llama-factory | verl | roll | mmdetection | ultralytics | transformers | custom-<project>
budget:
  time_budget_min: <int>         # wall-clock minutes per single experiment run in the loop
metric:
  name: <string>                 # e.g. val_bpb, mAP, F1, BLEU
  direction: minimize | maximize
baseline:
  value: <float>
  run_id: <string>                # commit hash or run identifier
current_best:
  value: <float>
  run_id: <string>
status: analyzing | designing | looping | done
```

Keep `current_best` and `status` up to date as the scenario progresses — other skills (especially `skills/experiment-loop/SKILL.md`) rely on `current_best` to decide keep/discard, and `knowledge/SKILL.md` relies on `status: done` to know a scenario is ready for write-back.

## Responsibilities

- **Create**: when Phase 1 starts a new scenario, create the directory and `scenario.yaml` with the fields above filled in as they become known (it's fine to fill `baseline` last, after the baseline run completes).
- **Read**: any skill needing scenario context should read `scenario.yaml` directly rather than asking the user to repeat information already recorded.
- **Update**: after every kept experiment in the loop, update `current_best` in `scenario.yaml`. Update `status` as the scenario moves through phases.
- **List/inspect**: if the user asks "what scenarios exist" or "what's the status of `<tag>`", list `scenarios/*/scenario.yaml`, report `status` and `current_best` vs `baseline` for each.

## Notes

- `scenario.yaml` is the contract other skills depend on — do not change its field names without updating every skill that reads it (`skills/experiment-loop/SKILL.md`, `trainer/SKILL.md`, `experiment_logs/SKILL.md`, `knowledge/SKILL.md`).
- This skill does not itself run training, pick models, or choose metrics — it only manages the scenario record. Delegate that work to `datasets/SKILL.md`, `models/SKILL.md`, `benchmark/SKILL.md`, and `trainer/SKILL.md` respectively.
