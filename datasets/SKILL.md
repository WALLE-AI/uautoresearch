---
name: dataset-analysis
description: Analyze a dataset sample (size, distribution, quality issues) and, when the existing data is insufficient, construct or synthesize new training data using frameworks like distilabel, dataagent, Magpie, or Evo-Instruct. Use this whenever a scenario needs data EDA before training, whenever the experiment loop's improve_guide.md falls back to a data-dimension change, or whenever the user asks about dataset quality, construction, or augmentation strategy.
---

# Dataset Analysis & Construction

Good data decisions are usually higher-leverage than hyperparameter tuning. This skill covers both understanding what data you have and, when necessary, building more or better data.

## When to use this skill

- Phase 1 (`skills/scenario-analysis/SKILL.md`) needs an EDA pass on the data sample before a baseline can be trusted.
- Phase 3 (`skills/experiment-loop/SKILL.md`) has exhausted architecture/hyperparameter ideas and falls back to the data-dimension plan in `improve_guide.md`.
- The user directly asks about data quality, coverage, or how to build more training data.

## Dataset EDA

For the domain of the current scenario (see `scenarios/SKILL.md` for `scenario.yaml`), check:

- **Size**: number of examples, tokens, or images; is it enough for the intended training method (full-FT needs more data than LoRA/PEFT)?
- **Distribution**: class balance (classification/detection), label distribution, sequence length distribution (LLM/NLP), image resolution/aspect ratio spread (CV/VLM).
- **Quality**: duplicate or near-duplicate examples, label noise, corrupted files, encoding issues, obviously wrong annotations (spot-check a sample).
- **Coverage**: does the data actually cover the scenarios the model will be evaluated/used on? Look for missing edge cases relative to the benchmark chosen in `benchmark/SKILL.md`.
- **Split integrity**: no leakage between train/val/test; val/test distribution should match the intended evaluation.

Summarize findings for `analysis_report.md`'s "Data quality" section — be specific (e.g. "12% of labels in class X are likely mislabeled based on manual spot-check of 50 samples", not "data quality seems okay").

## Dataset construction / synthesis

When more or better data is needed (especially common for LLM/VLM instruction data), use the appropriate framework. See `references/data-frameworks.md` for details on each — read it before choosing one, since they solve different problems:

- **distilabel** — general-purpose synthetic data generation pipelines (multiple LLM calls, filtering, scoring).
- **dataagent** — agent-driven data curation/generation workflows.
- **Magpie** — extracting high-quality instruction data directly from aligned LLMs without seed prompts.
- **Evo-Instruct** — evolutionary instruction complexity augmentation (evolving existing instructions to be more complex/diverse).

Pick based on what's missing: need more diverse instructions from scratch → Magpie; need to raise instruction difficulty/diversity of existing data → Evo-Instruct; need a general filtering/generation pipeline with custom stages → distilabel; need an agentic curation workflow → dataagent.

## Dataset registry

Keep a short record of every dataset used or constructed for a scenario in `datasets/README.md`-adjacent notes or directly referenced from `scenario.yaml` (e.g. a `dataset` field pointing to a path/description) — this repo does not currently version raw data, so record provenance (source, construction method, size, date) rather than the data itself.

## Notes

- Always prefer fixing/filtering existing data over training around known label noise, if the fix is cheap.
- When constructing synthetic data, generate a small sample first and have it spot-checked (by the user or against the benchmark) before scaling up generation — synthetic data quality problems compound silently.
