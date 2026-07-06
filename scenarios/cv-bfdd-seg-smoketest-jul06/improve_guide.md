# Improve Guide: cv-bfdd-seg-smoketest-jul06

**Scope note**: this scenario is a framework smoke test (see `analysis_report.md`). Candidates below are intentionally trivial, single-variable, and cheap — chosen to exercise the loop mechanics within a 12-minute budget per run, not to meaningfully move the metric. Run at most 1-2 of these before stopping and reporting to the user.

## Baseline
- metric: val_mIoU = 0.5997 (`xibeiyuan/checkpoints/bfdd_swin_base_ft/best.pth`)

## Candidate Techniques (ordered by priority)

1. **Learning rate bump for the finetune stage** — tier 4 — expected impact: low — cost: cheap
   - Rationale: fastest possible single-variable change to prove the loop can edit a config, launch a real run, and get a different metric back. `run_swin_base_ft_ddp.sh` uses `LR=5e-6` for this stage; trying `LR=1e-5` is a safe, bounded perturbation.
   - How to test: set `LR=1e-5` in the run config passed to `scripts/custom-bfdd-segmentation_run.sh` (see `trainer/references/custom-bfdd-segmentation.md`), keep all other args identical to the baseline finetune command.

2. **Early-stop patience reduction** — tier 4 — expected impact: low — cost: cheap
   - Rationale: with only ~12 minutes (≈40+ epochs at ~16s/epoch) available, a smaller `--early_stop` (e.g. 5 instead of 20) makes it more likely the run naturally stops on plateau within budget rather than being cut off by `timeout`, giving a cleaner test of the loop's crash-vs-discard-vs-keep logic.
   - How to test: set `EARLY_STOP=5` in the run config.

## Orthogonal Combination Plan

Not applicable for this smoke test — stop after validating 1-2 individual iterations rather than combining.

## Data-Dimension Fallback

Not applicable — this scenario intentionally does not touch data (see `analysis_report.md`, dataset already vetted by prior `xibeiyuan` work).
