---
name: benchmark-evaluation
description: Choose the evaluation benchmark and primary metric for a scenario, and execute evaluation runs to produce comparable numbers. Use this whenever a scenario needs its metric defined (Phase 1), whenever an improve guide needs to confirm what candidates are judged against (Phase 2), or whenever the experiment loop needs to actually run an eval to extract a metric.
---

# Benchmark & Evaluation

Defines what "better" means for a scenario and how to measure it consistently across every experiment in the loop.

## When to use this skill

- Phase 1: determine `scenario.yaml`'s `metric.name` and `metric.direction`.
- Phase 2: confirm which benchmark/eval set each candidate technique should be judged against.
- Phase 3: the read-only evaluation harness that `trainer/SKILL.md` wraps is defined here — never let the agent modify it (see `trainer/SKILL.md`'s read-only boundary rule).

## Steps

1. **Identify domain and task_type** from `scenarios/<tag>/scenario.yaml`.
2. **Pick the metric and direction** using `references/<domain>.md` (see table below) — do not invent a bespoke metric unless the standard ones genuinely don't fit the task; if you must, document why in `analysis_report.md`.
3. **Pick or build the eval set.** Prefer public/open benchmarks for the domain when applicable (see references); otherwise use a held-out split of the scenario's own data, sized and constructed per `datasets/SKILL.md` guidance (no leakage from train).
4. **Define the evaluation procedure**: how the eval is invoked (which script/entrypoint in the trainer engine), what it outputs, and how the number is extracted — this becomes the read-only "evaluation harness" that the experiment loop is not allowed to modify.
5. **Record it** in `scenario.yaml` (`metric.name`, `metric.direction`) and describe the eval set/procedure in `analysis_report.md`.

## Reference index (read the one matching the scenario's domain)

- `references/llm-vlm.md` — LLM/VLM metrics (perplexity/bpb, task accuracy, preference win-rate) and public benchmark pointers.
- `references/cv.md` — CV metrics (accuracy, mAP, mIoU) and public benchmark pointers.
- `references/nlp.md` — NLP metrics (F1, accuracy, BLEU/ROUGE) and public benchmark pointers.

## Notes

- **Vocab/scale independence matters.** When comparing architectural changes (e.g. different tokenizers or vocab sizes for LLM), prefer a metric that stays comparable across those changes (e.g. bits-per-byte instead of raw loss/perplexity), following the same reasoning as `opensource/autoresearch`'s use of `val_bpb`.
- **Never let the experiment loop touch the evaluation code.** If a technique genuinely requires changing how evaluation works, that's a Phase 2 design discussion with the human, not something Phase 3 does unilaterally.
- Keep the eval fast enough to run within (or a small fraction of) `time_budget_min` — a benchmark that takes longer than the training budget itself defeats the purpose of the fixed-budget loop.
- If the scenario's task has a well-known public leaderboard/benchmark, cite it in `analysis_report.md` even if the actual eval used is a smaller held-out split — this helps `knowledge/SKILL.md` cross-reference results across scenarios later.
