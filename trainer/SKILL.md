---
name: trainer-engine
description: Select and operate the pluggable training engine for a scenario (LLaMA-Factory/veRL/ROLL for LLM/VLM, mmdetection/ultralytics for CV, transformers Trainer for NLP), including the read-only vs editable file boundary and the unified launch/log/budget conventions the experiment loop depends on. Use this whenever a scenario needs a trainer engine chosen, whenever the experiment loop needs to know what it may or may not edit, or when wiring up a new engine.
---

# Trainer Engine (Plugin Layer)

This skill is the contract between the domain-agnostic experiment loop (`skills/experiment-loop/SKILL.md`) and the concrete open-source training frameworks. It defines a uniform interface so the loop never needs domain-specific logic.

## Engine selection

| Domain | Engine | Reference |
|---|---|---|
| LLM (SFT/RLHF/FT) | LLaMA-Factory | `references/llama-factory.md` |
| LLM/VLM (RL-heavy: RLHF/RLVR at scale) | veRL | `references/verl.md` |
| LLM/VLM (RL, alternative) | ROLL | `references/roll.md` |
| CV (detection/segmentation) | mmdetection | `references/mmdetection.md` |
| CV (detection, fast iteration) | ultralytics | `references/ultralytics.md` |
| NLP (classification/generation, general) | transformers Trainer | `references/transformers.md` |
| Bespoke/pre-existing research codebase not covered above | custom (one adapter per project) | `references/custom-<project>.md`, e.g. `references/custom-bfdd-segmentation.md` |

Pick the engine jointly with `models/SKILL.md` (the model must actually be supported by the engine) during Phase 1, and record it as `trainer_engine` in `scenario.yaml`. Read the matching reference file before running anything — each engine has different read-only/editable boundaries and launch conventions.

If a scenario's training code doesn't fit any of the six standard engines (e.g. it's an existing hand-written DDP script the user already had before adopting this framework), write a new `references/custom-<project>.md` following the same structure as the standard ones (Editable / Read-only / Launch convention / Budget mapping / Metric extraction / Common pitfalls) rather than forcing the scenario into a standard engine it doesn't actually use. Use `references/custom-bfdd-segmentation.md` as the template.

## Universal plugin interface (L2 protocol)

Every engine adapter must conform to this, regardless of domain:

### Launch convention

```
scripts/<engine>_run.sh <config> <time_budget_min>
```

The wrapper script (built via `scripts/SKILL.md`) is responsible for:
- Passing `<config>` through to the underlying engine's native config format (yaml/json/CLI args).
- Enforcing the time budget: either via the engine's native max-time/max-steps setting, or by having the wrapper itself terminate the process gracefully (checkpoint if possible) when `time_budget_min` elapses.
- Writing all stdout/stderr to `experiment_logs/<tag>/runs/<candidate>/run.log` — **not** into the engine's own `RUN_DIR`/checkpoint directory (that directory still holds weights/artifacts/native results files; only the log text is centralized). See `experiment_logs/SKILL.md`.

### Read-only vs editable boundary (general rule)

- **Read-only, never edit**: data loading/collation code, the evaluation/scoring function (owned by `benchmark/SKILL.md`), and anything the specific engine reference marks as core library internals.
- **Editable**: training config (yaml/json), hyperparameters, and — only where the engine reference explicitly allows it — model architecture code or custom modules.
- If an experiment idea requires touching a read-only file, it is out of scope for the automated loop; surface it to the human instead.

### Unified log fields (written to `run.log`, must be greppable)

```
metric_name:      <string, matches scenario.yaml metric.name>
metric_value:     <float>
training_seconds: <float>
total_seconds:    <float>
peak_vram_mb:     <float>
num_params_M:     <float>
```

Domain-specific extra fields are allowed (e.g. `num_steps`, `mfu_percent`) but the six above must always be present so `experiment_logs/SKILL.md` can parse them uniformly regardless of engine.

### Budget field

- **Primary**: `time_budget_min` — the only budget unit compared across engines/domains. Always use this for keep/discard decisions and for scenario-level comparability.
- **Secondary (engine-internal only)**: engines may also expose `max_steps`, `num_epochs`, etc. for their own internal scheduling — never use these to compare across different engines or domains.

## Adapter checklist when wiring up a new engine

1. Confirm the engine can be launched non-interactively from a config file/CLI args (required for the loop to drive it unattended).
2. Confirm it supports a way to bound wall-clock time (native flag, or wrap it with an external timeout that still allows graceful checkpoint/log flush).
3. Identify exactly which files/config sections are safe to edit vs. which are core library internals — document this explicitly in the engine's reference file, don't leave it implicit.
4. Confirm the evaluation output can be mapped to the six unified log fields above.
5. Write or update `scripts/<engine>_run.sh` per `scripts/SKILL.md`.

## Notes

- Never install new dependencies or upgrade an engine version mid-scenario without the human's approval — this can silently invalidate comparisons between earlier and later experiments in the same loop.
- If VRAM usage (`peak_vram_mb`) is not reported natively by an engine, add a lightweight wrapper (e.g. polling `nvidia-smi` or the framework's own memory stats API) rather than skipping the field.
