# LLaMA-Factory Adapter Notes

General-purpose fine-tuning engine for LLMs (and some VLMs), covering full fine-tune, LoRA/QLoRA, and RLHF-style methods (DPO/PPO/KTO) through a single YAML-config-driven CLI.

## Editable

- The training YAML config (learning rate, batch size, LoRA rank/target modules, number of epochs/steps, dataset selection, template).
- Dataset registration entries (`dataset_info.json`-style registration), when adding a new dataset variant.

## Read-only

- Core library code (model loading, trainer implementation) unless the scenario explicitly calls for a custom architecture modification — treat this as a Tier-1 (architecture) decision requiring human sign-off, not something the automated loop does unilaterally.
- The evaluation/scoring implementation used to compute the scenario's metric — owned by `benchmark/SKILL.md`.

## Launch convention

`scripts/llama-factory_run.sh <config.yaml> <time_budget_min>` should invoke the LLaMA-Factory CLI training entrypoint with the given config, and either rely on a `max_steps`/time-based stopping config field or wrap the process with an external timeout that still allows the framework to save a final checkpoint and flush logs.

## Budget mapping

Convert `time_budget_min` to an approximate `max_steps` or `num_train_epochs` for the initial config (based on a quick throughput estimate from the baseline run), then keep the external wall-clock wrapper as the authoritative cutoff — engine-internal step counts drift as batch size/sequence length change between experiments.

## Metric extraction

LLaMA-Factory logs training/eval loss and, depending on task, task-specific metrics to its trainer log. Parse the relevant eval metric from the log output at the end of the run and map it to `metric_value`; map peak GPU memory (from `torch.cuda.max_memory_allocated` or the framework's own reporting) to `peak_vram_mb`.

## Common pitfalls

- LoRA rank increases can silently blow up VRAM if target modules are expanded at the same time — treat rank and target-module-set as related but distinct experiment variables in `improve_guide.md`.
- Template mismatches (wrong chat template for the base model) silently degrade results without crashing — verify the template matches `base_model` during Phase 1, not mid-loop.
