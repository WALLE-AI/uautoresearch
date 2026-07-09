---
name: training-plan
description: Synthesize the Scenario-Analysis, Dataset-Analysis, and Model-Selection Agents' Phase 1 outputs into one concrete, executable training plan — hardware/software resource allocation and a training calendar (epoch/time-phase breakdown with an estimated total duration). Use this after a scenario's baseline is confirmed and before Phase 2 (experiment design) starts, and again whenever Phase 3's loop exhausts its budget without reaching the user's target metric (re-planning).
---

# Training Plan Generation

This skill produces the single artifact that turns "we know the domain/model/data" into "here is exactly how much compute this will take and in what order training phases happen." `skills/experiment-design/SKILL.md` treats this as a hard constraint, not a suggestion.

## When to use this skill

- Phase 1 is finished (`scenario.yaml`, `analysis_report.md` exist, baseline confirmed) and Phase 2 has not started yet.
- Phase 3's loop ended because the time budget was exhausted and `scenario.yaml`'s `metric.target` was not reached — the Orchestrator routes back here to revise the plan before another design pass.

## Steps

1. **Read the scenario record**: `scenario.yaml` (`domain`, `task_type`, `base_model`, `trainer_engine`, `budget.time_budget_min`, `compute`, `metric`), `analysis_report.md`.
2. **Read the Dataset-Analysis Agent's EDA summary** (size, distribution, quality) to size batch/epoch counts realistically.
3. **Read the Model-Selection Agent's baseline + architecture candidates** to know what the model actually requires (parameter count, memory footprint).
4. **Read `trainer/references/<engine>.md`** for the engine's supported acceleration techniques and native resource requirements.
5. **Build the resource plan**: GPU type/count and VRAM headroom, CPU/RAM/storage, software environment (OS/CUDA/framework versions). Cross-check against `scenario.yaml`'s `compute` block (what the user actually has) — flag a mismatch instead of assuming more hardware exists.
6. **Build the training calendar**: break the total `time_budget_min` (or the user's overall time budget, if larger than one experiment's budget) into named phases appropriate to the domain (e.g. warmup → main convergence → fine-tune → EMA+eval for CV/vision; warmup → stable-phase → decay for LLM pretraining/SFT). Give an estimated duration per phase and a total.
7. **Select key techniques**: from what the engine supports (mixed precision, gradient checkpointing, FlashAttention, EMA, DDP/DeepSpeed, LoRA, etc.), pick the ones that make the calendar realistic within the resource plan.
8. **Write `training_plan.md`** (template below).
9. **Hand off to `skills/experiment-design/SKILL.md`** — its Tier 4 (schedule) candidates must stay consistent with the calendar produced here.

## Output format

`scenarios/<tag>/training_plan.md`:

```markdown
# Training Plan: <tag>

## Resource Plan
- GPU: <type> x <count>, VRAM <GB> each
- CPU / RAM / Storage
- Software: OS / CUDA / framework version (see trainer/references/<engine>.md)

## Training Calendar
| Phase | Epoch/step range | Est. duration | Notes |
|---|---|---|---|
| Warmup | ... | ... | ... |
| Main convergence | ... | ... | ... |
| Fine-tune | ... | ... | ... |
| EMA + Eval | ... | ... | ... |
- Estimated total duration: <hours>

## Key Techniques
- Mixed precision / gradient checkpointing / FlashAttention / EMA / DDP+DeepSpeed, etc. (pick per domain and engine support)

## Constraints for improve_guide.md
(Tier 4 schedule candidates must stay within this calendar and resource plan — do not propose a schedule change that needs more GPUs/VRAM than the Resource Plan states)
```

## Re-planning (invoked after a Phase 3 loop ends without reaching target)

1. Read `experiment_logs/<tag>/experiment_results.csv` and the newly written `knowledge/` entries for this scenario.
2. Identify whether the shortfall looks like a **resource** problem (ran out of time/GPU before converging — extend the calendar or request more compute) or an **approach** problem (plateaued well within budget — the plan itself was fine, Phase 2 needs new candidates, not a new plan).
3. If it's a resource problem, revise `training_plan.md` in place (new calendar/resource section) and note what changed and why.
4. If it's an approach problem, say so explicitly and hand back to Phase 2 without changing `training_plan.md` — do not touch a plan that wasn't the actual bottleneck.
5. If the target looks unreachable even after revision (e.g. compute available is fundamentally insufficient for the model size), stop and report this to the human rather than proposing a third revision blindly.

## Notes

- Keep the calendar concrete enough that the Trainer Agent's schedule-tier candidates in `improve_guide.md` can be written directly against it.
- Never propose a plan requiring more GPUs/VRAM than `scenario.yaml`'s `compute` block states are available — surface the gap to the human instead of inventing hardware.
