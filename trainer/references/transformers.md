# transformers Trainer Adapter Notes

General-purpose training loop (`transformers.Trainer`/`Seq2SeqTrainer`) for NLP classification, sequence labeling, and generation tasks, and a reasonable fallback for any domain when a more specialized engine isn't warranted.

## Editable

- `TrainingArguments` (learning rate, batch size, epochs/max steps, warmup, weight decay, mixed precision, gradient accumulation).
- Model head configuration (number of labels, dropout) and tokenizer/preprocessing settings (max length, truncation strategy).
- Custom data collators, when the task needs one.

## Read-only

- The core `Trainer` training loop internals.
- The `compute_metrics` function once it has been designated as the scenario's evaluation harness by `benchmark/SKILL.md` — changing it mid-loop invalidates comparisons.

## Launch convention

`scripts/transformers_run.sh <config> <time_budget_min>` should invoke a training script that builds `TrainingArguments` from `<config>` and calls `Trainer.train()`, bounding time via `max_steps` calibrated from a quick throughput check, with an external wall-clock wrapper as the final authority since step time varies with sequence length/batch size across experiments.

## Budget mapping

Estimate steps/second from the baseline run at the chosen batch size and sequence length, then set `max_steps` accordingly for subsequent experiments — but always keep the external time wrapper active, since later experiments may change batch size or sequence length and shift step time.

## Metric extraction

`Trainer` logs `eval_*` metrics (from `compute_metrics`) at each evaluation; take the final (or best) eval metric per `scenario.yaml`'s `metric.direction` and map it to `metric_value`. Peak memory can be read via `torch.cuda.max_memory_allocated()` if not already logged.

## Common pitfalls

- Distributed/mixed-precision (FSDP/DeepSpeed) settings can change effective batch size and thus optimal LR — if switching between single-GPU and distributed setups mid-scenario, treat it as a Tier-1 change, not an incidental config tweak.
- For imbalanced classification, make sure `compute_metrics` reports macro-F1 (per `benchmark/references/nlp.md`), not just accuracy, before trusting keep/discard decisions.
