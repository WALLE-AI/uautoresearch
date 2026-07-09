---
name: experiment-design
description: Phase 2 orchestration skill for uautoresearch. Use after a scenario has a confirmed baseline and a training plan (`scenario.yaml`, `analysis_report.md`, and `training_plan.md` exist) and the user wants a concrete plan of what to try to improve the metric — matching candidate techniques, expanding hyperparameter tiers, and deciding what the automated experiment loop should attempt first. Produces `improve_guide.md`.
---

# Phase 2: Experiment Design

This skill converts a validated baseline into a prioritized, concrete plan of experiments. The plan is what `skills/experiment-loop/SKILL.md` will mechanically work through, so it needs to be specific enough to act on without further human input.

## Inputs

- `scenarios/<tag>/scenario.yaml`, `analysis_report.md`, and `training_plan.md` (Training-Plan Agent's resource plan/training calendar) from Phase 1/Planning
- The technique candidate library for the scenario's domain (see below)

## Steps

1. **Read the scenario and training plan.** Load `domain`, `task_type`, `base_model`, `trainer_engine`, the baseline metric value, and `training_plan.md`'s resource/calendar constraints (they bound how many candidates can realistically be tried and in what order).
2. **Match candidate techniques for the domain:**
   - **LLM**: LR schedule/warmup, optimizer choice (AdamW/Muon), batch size, sequence length/packing, LoRA rank/target modules, full-FT vs PEFT, data mixing ratios, RLHF/RLVR reward shaping, quantization-aware training.
   - **VLM**: vision encoder freezing strategy, projector architecture, image resolution/tiling, instruction data mixing, multi-stage training (align → instruct).
   - **CV**: backbone choice (see `models/SKILL.md`), augmentation policy, anchor/loss design (for detection), input resolution, multi-scale training, EMA, label smoothing.
   - **NLP**: tokenization/vocab choice, class imbalance handling, prompt design (for generative NLP), decoding strategy for generation tasks.
   - Consult `models/SKILL.md` for architecture-level options and `knowledge/SKILL.md` for what has already worked or failed on similar scenarios — do not propose something the knowledge base already recorded as a discard.
3. **Expand into a tiered parameter checklist.** Organize candidates from broad architectural choices down to fine-grained hyperparameters, roughly:
   - Tier 1: architecture/engine choice
   - Tier 2: data strategy (mixing, augmentation, filtering)
   - Tier 3: training method (full-FT/LoRA/RLHF, optimizer)
   - Tier 4: schedule (LR, warmup, batch size)
   - Tier 5: regularization/stability (dropout, label smoothing, EMA, gradient clipping)
   - Tier 6: fine-grained knobs (specific layer configs, seed, minor architectural tweaks)
4. **Determine the evaluation basis.** Confirm with `benchmark/SKILL.md` which benchmark/eval set and metric direction (minimize/maximize) each candidate should be judged against — this should already match `scenario.yaml`'s `metric` field.
5. **Order candidates by expected impact vs. cost** given the fixed `time_budget_min` per run. Put single-variable, cheap-to-test, high-expected-impact changes first (this is what the loop will try first).
6. **Write `improve_guide.md`.**

## Output format

`scenarios/<tag>/improve_guide.md`:

```markdown
# Improve Guide: <tag>

## Baseline
- metric: <name> = <value>

## Candidate Techniques (ordered by priority)
1. <technique> — tier <N> — expected impact: <low|med|high> — cost: <cheap|moderate|expensive>
   - Rationale:
   - How to test: <what to change, in which file/config>
2. ...

## Orthogonal Combination Plan
(which single-variable wins from the list above should be combined together once each is individually validated)

## Data-Dimension Fallback
(if architecture/hyperparameter tuning plateaus, what data-side changes to try — e.g. more data, filtering, re-labeling, synthetic augmentation via `datasets/SKILL.md`)
```

## Notes

- Keep each candidate entry concrete enough that `skills/experiment-loop/SKILL.md` can act on it without re-deriving what to change.
- Do not propose changes that violate the trainer engine's read-only boundaries — check `trainer/SKILL.md` before finalizing the guide.
- Once `improve_guide.md` is written, update `scenario.yaml`'s `status` to `looping` and hand off to `skills/experiment-loop/SKILL.md`.
