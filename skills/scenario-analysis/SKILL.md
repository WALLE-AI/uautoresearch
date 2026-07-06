---
name: scenario-analysis
description: Phase 1 orchestration skill for uautoresearch. Use when the user provides a research goal, a data sample, and a budget, and needs the scenario understood and diagnosed before any experimentation starts — determining the domain (CV/NLP/LLM/VLM), task type, baseline model, and whether the base model/data are even suitable for the task. Also use when re-diagnosing an existing scenario whose baseline results look wrong. Produces `analysis_report.md` and `scenario.yaml`.
---

# Phase 1: Scenario Analysis

This skill turns a vague research request into a concrete, machine-readable scenario definition and a validated baseline. Everything downstream (experiment design, the automated loop, knowledge write-back) depends on `scenario.yaml` being correct, so do not rush this phase.

## Inputs

- Research goal (free text from the user)
- Data sample or a pointer to the dataset
- Budget: total time/compute available (this becomes `time_budget_min` per experiment, not the total budget — clarify with the user if ambiguous)
- Domain, if known (CV / NLP / LLM / VLM) — infer it from the goal and data if not stated

## Steps

1. **Determine the domain and task type.** Look at the data sample and goal. Examples: image classification (CV), object detection (CV), semantic segmentation (CV), text classification (NLP), text generation (NLP), instruction SFT (LLM), RLHF/RLVR (LLM), image-text alignment (VLM). If genuinely ambiguous, ask the user.
2. **Run the 7-dimension diagnosis** before assuming any baseline is adequate:
   - Base model suitability (is a pretrained checkpoint appropriate for this domain/task?)
   - Data quality (label noise, class imbalance, duplicates, coverage)
   - Prompt/task formulation (for LLM/VLM: is the prompt template sound?)
   - Training method fit (full fine-tune vs LoRA vs RLHF vs from-scratch, given data size and budget)
   - Evaluation soundness (does the eval set actually measure what matters?)
   - Baseline history (has anyone tried this before — check `knowledge/` first via `knowledge/SKILL.md`)
   - Compute/hardware fit (does the available GPU support the intended model size and batch size?)
3. **Dataset EDA.** Delegate to `datasets/SKILL.md` to analyze the data sample (size, distribution, quality issues) and register it.
4. **Baseline model selection.** Delegate to `models/SKILL.md` to pick a baseline model/architecture appropriate for the domain and task, informed by the diagnosis above.
5. **Determine the evaluation metric.** Delegate to `benchmark/SKILL.md` to decide the primary metric for this domain/task (e.g. `val_bpb`/perplexity for LLM pretraining, accuracy/F1 for classification, mAP for detection, mIoU for segmentation, BLEU/ROUGE for generation).
6. **Run the baseline.** Delegate to `trainer/SKILL.md` to pick the trainer engine for this domain, then to `scripts/SKILL.md` to actually launch a single baseline run within the intended `time_budget_min`. Record the result.
7. **Propose a run tag.** Suggest a tag based on today's date and the scenario, e.g. `cv-detect-jul06`. Confirm with the user that `scenarios/<tag>/` does not already exist.
8. **Write the outputs** (see Output format below) into `scenarios/<tag>/`.
9. **Confirm with the user** that the scenario, baseline, and metric look right before handing off to Phase 2 (`skills/experiment-design/SKILL.md`).

## Output format

### `scenarios/<tag>/scenario.yaml`

```yaml
tag: <run-tag>
domain: cv | nlp | llm | vlm
task_type: <e.g. object-detection, instruction-sft, text-classification>
base_model: <model name/checkpoint>
trainer_engine: <llama-factory | verl | roll | mmdetection | ultralytics | transformers>
budget:
  time_budget_min: <int>          # wall-clock minutes per single experiment run
metric:
  name: <e.g. val_bpb, mAP, F1, BLEU>
  direction: minimize | maximize
baseline:
  value: <float>
  run_id: <commit hash or run id>
```

### `scenarios/<tag>/analysis_report.md`

Use this exact template:

```markdown
# Scenario Analysis: <tag>

## Goal
## 7-Dimension Diagnosis
### Base model suitability
### Data quality
### Prompt/task formulation
### Training method fit
### Evaluation soundness
### Baseline history (from knowledge/)
### Compute/hardware fit
## Baseline Result
## Open Risks
```

## Notes

- Never skip step 6 (running the actual baseline). A scenario without a real, measured baseline number is not ready for Phase 2.
- If the 7-dimension diagnosis surfaces a blocker (e.g. the base model is fundamentally unsuited, or data quality is too poor), stop and report this to the user instead of proceeding — do not silently push forward with a doomed baseline.
