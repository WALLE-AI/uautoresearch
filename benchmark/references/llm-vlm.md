# LLM / VLM Evaluation Reference

## Metrics

| Task | Metric | Direction |
|---|---|---|
| Pretraining / language modeling | bits-per-byte (bpb) or perplexity | minimize |
| Instruction following (SFT) | task accuracy on held-out instructions, or LLM-judge win-rate vs. reference | maximize |
| RLHF/RLVR | reward model score, or verifiable task pass-rate (for RLVR) | maximize |
| Preference alignment | win-rate in pairwise comparison (human or LLM-judge) | maximize |
| VLM instruction/QA | task accuracy on held-out VQA-style eval, or LLM-judge score | maximize |
| VLM alignment stage | image-text retrieval accuracy or captioning quality (CIDEr) | maximize |

Prefer **bits-per-byte over raw loss/perplexity** when comparing runs that might change tokenizer or vocab size — bpb stays comparable, following `opensource/autoresearch`'s `val_bpb` convention.

## Public benchmark pointers

- General LLM capability: MMLU, GSM8K (math/reasoning), HumanEval (code).
- Instruction-following quality: AlpacaEval, MT-Bench.
- RLVR / verifiable reasoning: task-specific pass@1 on held-out verifiable problems (math, code) matching the RL reward signal.
- VLM: MMBench, MME, VQAv2, TextVQA depending on the capability being trained.

Use these as reference points for sanity-checking, but for the fast experiment loop, prefer a smaller held-out slice that runs within the fixed time budget — full public benchmark suites are usually too slow to run every iteration.

## Evaluation harness boundary

The evaluation code (dataloader for the eval set, scoring function) should be treated as read-only during Phase 3, matching the role of `evaluate_bpb` in `opensource/autoresearch/prepare.py`. Only the training config/architecture is fair game for the loop to edit.
