# NLP Evaluation Reference

## Metrics

| Task | Metric | Direction |
|---|---|---|
| Text classification | accuracy / macro-F1 (prefer macro-F1 if classes are imbalanced) | maximize |
| Sequence labeling (NER, etc.) | entity-level F1 | maximize |
| Text generation (summarization, translation) | ROUGE / BLEU (+ human or LLM-judge spot-check) | maximize |
| Text understanding (NLI, QA) | accuracy / exact-match / F1 | maximize |

## Public benchmark pointers

- Classification/understanding: GLUE/SuperGLUE-style tasks.
- Generation: CNN/DailyMail (summarization), WMT (translation).
- QA: SQuAD-style extractive QA.

For domain-specific NLP (e.g. legal, medical, customer support text), prefer a held-out split of the scenario's own labeled data over generic public benchmarks.

## Evaluation harness boundary

The scoring function (F1/BLEU/ROUGE computation, exact-match logic) is read-only during Phase 3. Tokenization strategy, model choice, and training hyperparameters are editable, subject to `trainer/SKILL.md`'s engine-specific boundaries.

## Notes

- BLEU/ROUGE are known to correlate imperfectly with actual quality for generation tasks — where feasible, pair them with a small LLM-judge or human spot-check before trusting a "keep" decision based on automatic metrics alone.
- For imbalanced classification, always report macro-F1 alongside accuracy — a model that always predicts the majority class can still show high accuracy.
