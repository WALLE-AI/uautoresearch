# Final Report: cv-bfdd-seg-smoketest-jul06

**Purpose**: feasibility smoke test of the uautoresearch Markdown-agent loop against a real, pre-existing training codebase (`xibeiyuan/train_bfdd_swin.py`) and 8×A100 40GB hardware — not a real optimization run. Result: **framework mechanics fully validated.**

## What was proven end-to-end

1. **New "custom" trainer engine pattern works.** `trainer/references/custom-bfdd-segmentation.md` (following `trainer/SKILL.md`'s adapter checklist) correctly wraps a bespoke `torchrun` DDP script that doesn't match any of the 6 standard engines.
2. **Launch wrapper (`scripts/custom-bfdd-segmentation_run.sh`) works**:
   - Launches the real 8-GPU DDP job non-interactively.
   - Enforces `time_budget_min` via `timeout --signal=TERM` (graceful stop, confirmed safe against checkpoint corruption since checkpoints only save on new-best).
   - Correctly detects and reports a "crash" (no metric produced) when a 2-minute test budget was too short for dataset/copy-paste-pool warmup — validated in a preliminary manual test before the real 12-minute runs.
   - Correctly appends all six unified `run.log` fields (`metric_name`, `metric_value`, `training_seconds`, `total_seconds`, `peak_vram_mb`, `num_params_M`) on successful completion.
3. **Metric extraction, keep/discard comparison, and CSV ledger work** — see `experiment_logs/cv-bfdd-seg-smoketest-jul06/experiment_results.csv`.

## Results

| iter | change | metric_value (val_mIoU) | vs baseline (0.5801) | status | epochs run | wall time |
|---|---|---|---|---|---|---|
| 1 | LR 5e-6 → 1e-5 | 0.5682 | worse | discard | 21 (early-stopped) | 222s train / 426s total |
| 2 | early_stop 20 → 5 | 0.5782 | worse (marginal) | discard | 6 (early-stopped) | 64s train / 268s total |

`current_best` remains the original baseline (`xibeiyuan/checkpoints/bfdd_swin_base_ft/best.pth`, val_mIoU=0.5801) — no experiment beat it, which is expected for two single-epoch-scale, low-effort smoke-test perturbations and is not a meaningful research finding.

## Hardware/timing notes for future real runs on this scenario

- ~10-12s/epoch on 8×A100 40GB at 1024×1024, batch=2/GPU, accumulate=4 — much faster than the ~16s/epoch seen in `xibeiyuan/logs/*.log` at the same settings but earlier in training (likely dataloader/cudnn-benchmark warm caches by iter2). A 12-minute budget is generous (fits 40+ epochs); a real research loop for this scenario could use a shorter per-run budget (e.g. 5 min) to iterate faster, or a longer one (e.g. 30-60 min) if deeper convergence per experiment is desired.
- Startup overhead (dataset stem loading, per-class pixel weight estimation, 8× redundant copy-paste pool building) takes ~60-90s before epoch 1 starts — factor this into budget choices; anything below ~3 min will likely never complete an epoch.
- Peak VRAM ~17GB/run at these settings — well under the 40GB/GPU limit, room to increase batch size or resolution in a real research pass.

## Recommendation

The uautoresearch framework is **feasible for this dataset/model/hardware combination**. To proceed with real research (not just this smoke test), the user should re-run Phase 2 (`skills/experiment-design/SKILL.md`) with a full, ambitious `improve_guide.md` (the current one was deliberately trivial) and let Phase 3 run unattended for a real time budget (hours, not one manual iteration at a time).
