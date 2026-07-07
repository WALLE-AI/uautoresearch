---
name: model-selection
description: Select an appropriate base model or network architecture for a given scenario (domain, task type, data size, compute budget). Use this whenever Phase 1 needs a baseline model choice, Phase 2 needs architecture-level candidates for the improve guide, or the user directly asks "what model should I use for X".
---

# Model Selection

Picks the right starting point so later experimentation isn't wasted compensating for a fundamentally wrong model choice.

## Inputs

- `domain` and `task_type` from `scenarios/<tag>/scenario.yaml`
- Data size and quality summary from `datasets/SKILL.md`
- Available compute (GPU count/memory) — ask the user if not already known

## Selection guidance by domain

### LLM
- Small data / limited compute → prefer PEFT (LoRA) on a strong open base (e.g. Qwen, Llama, Mistral family) sized to fit the GPU with the intended batch size and sequence length.
- Pretraining-from-scratch research (like `opensource/autoresearch`) → start from the smallest architecture that fits the time budget, scale depth/width as experiments allow.
- RLHF/RLVR → start from an already-instruction-tuned checkpoint, not a raw base model.

### VLM
- Prefer a proven vision encoder (e.g. SigLIP/CLIP family) paired with a strong LLM backbone unless the scenario specifically requires a novel architecture.
- For small data, freeze the vision encoder initially and only train the projector + LLM (or just the projector) before considering full unfreezing.

### CV
- Classification: start from an ImageNet-pretrained backbone appropriate to the data size (smaller backbone for small data, to avoid overfitting).
- Detection/segmentation: pick a backbone + head combination supported by the chosen trainer engine (see `trainer/references/mmdetection.md` or `trainer/references/ultralytics.md`) that matches the latency/accuracy tradeoff the user needs.
- Always check that the chosen architecture is actually supported end-to-end by the trainer engine before finalizing — don't pick a model the engine can't train.

### NLP
- Classification/understanding tasks with moderate data → encoder-only pretrained model (e.g. BERT/RoBERTa family) fine-tuned with `transformers.Trainer`.
- Generation tasks → decoder or encoder-decoder pretrained model sized to the data/compute budget.

## Steps (Phase 1 — baseline selection)

1. Read the scenario's domain/task_type and the data summary.
2. Shortlist 1-3 candidate base models/architectures using the guidance above.
3. Check each candidate is actually trainable with the `trainer_engine` already chosen (or help choose the engine jointly with `trainer/SKILL.md` if not yet decided) and fits the available VRAM at a reasonable batch size.
4. Recommend one as the baseline choice for `scenario.yaml`'s `base_model` field.
5. Record the rationale briefly — this feeds into `analysis_report.md` and later into `knowledge/SKILL.md`.

## Network-architecture optimization (Phase 2 — separate from baseline selection)

This is a distinct output from step 4 above, produced when `skills/experiment-design/SKILL.md` asks for Tier-1 (architecture) candidates for `improve_guide.md`. Do not fold these into the baseline recommendation — they are things to *try changing* from the baseline, not the baseline itself.

Propose candidates at the architecture level, not the hyperparameter level (hyperparameters belong to the Trainer Agent's tiers 3-6 in `skills/experiment-design/SKILL.md`):

- **CV**: backbone swap (e.g. yolo11x -> rtdetr_v2), neck/FPN variant, detection/segmentation head design, multi-scale input handling, EMA.
- **LLM**: LoRA target-module set/rank tier as an architecture-shape choice (not the LR that trains it), attention variant if the engine supports swapping it.
- **VLM**: vision-encoder freeze/unfreeze boundary, projector architecture (MLP vs. Q-Former-style), multi-stage training topology (align-then-instruct vs. joint).
- **NLP**: encoder vs. encoder-decoder choice, pooling/classification-head design.

For each candidate: confirm with the Trainer Agent (`trainer/AGENT.md`) that the chosen `trainer_engine` can actually train it end-to-end before adding it to `improve_guide.md` — an architecture idea the engine can't run is not a valid candidate, no matter how promising on paper.

## Notes

- Prefer well-supported, widely-used checkpoints over exotic ones — training engine compatibility and community-known quirks matter more than marginal benchmark differences at baseline stage.
- If `knowledge/SKILL.md` shows a specific model or architecture change already failed for a very similar scenario, do not re-propose it without addressing why it failed.
