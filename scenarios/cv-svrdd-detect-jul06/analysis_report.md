# Phase 1 Analysis: SVRDD Road Distress Detection

## Task

7-class road distress object detection on the SVRDD dataset (`/home/dataset1/gaojing/xibeiyuan/datasets/SVRDD/SVRDD_YOLO`):
Longitudinal Crack, Transverse Crack, Alligator Crack, Pothole, Longitudinal Patch, Transverse Patch, Manhole Cover.

## Dataset facts

- 6000 train / 1000 val / 1000 test images, standard YOLO-format labels (`class cx cy w h`, normalized).
- 20,804 total instances; class imbalance — Pothole is the rarest class (~4.4% of instances).
- Absolute-path split files (`train_abs.txt`, `val_abs.txt`, `test_abs.txt`) already exist, used directly in `configs/data.yaml`.
- `grid_labels*` variants excluded from scope per user decision (not standard detection annotations).

## Target metric

User-specified target: **mAP50-95 > 0.9**. This is called out explicitly here because it is very unlikely to be
reached — comparable road-crack detection literature typically reports mAP50-95 in the 0.4-0.6 range, with SOTA
rarely exceeding 0.7, due to the thin/elongated/low-contrast nature of crack classes under strict IoU thresholds.
Per user direction, the experiment loop (Phase 3) proceeds to full time-budget exhaustion regardless, and the
final gap to 0.9 is reported honestly in `final_report.md`.

## Model/engine selection

- **Environment fix applied (approved by user)**: upgraded `ultralytics` 8.3.57 -> 8.4.89. Root cause: (1) `yolo26n.pt`
  is exported from a newer ultralytics model definition (`SPPF` signature mismatch) incompatible with 8.3.57;
  (2) `yolo11x` training crashed at validation under numpy 2.4.6 because 8.3.57 calls the removed `np.trapz`.
  Both are fixed by the upgrade; re-verified with smoke tests (1-minute budget, both models) after upgrading.
- **Candidates running as Phase 1 baselines** (`trainer_engine: ultralytics`):
  - `yolo11x` (`models/yolo11x/yolo11x.pt`, ~56.9M params) — GPU 0, batch 32.
  - `yolo26n` (`models/yolo26n/yolo26n.pt`, ~2.5M params) — GPU 1, batch 64.
  - Both launched via `scripts/ultralytics_run.sh` in `tmux` session `svrdd_baseline` (windows `yolo11x`/`yolo26n`),
    `time_budget_min=300` (5h), `data.yaml` at `configs/data.yaml`. Ultralytics' native `time=` argument dynamically
    estimates total epochs to fit the budget (yolo11x: ~109-117 epochs; yolo26n: ~368 epochs observed at smoke-test rate).
  - `rtdetr_v2_r18vd` recorded as a Tier-1 architecture candidate for Phase 2 if yolo11x/yolo26n plateau (requires
    a new `trainer/references/custom-rtdetr.md` or confirming ultralytics RT-DETR support — not yet investigated).
- **GroundingDINO — ruled out as a fine-tuning candidate.** Feasibility probe: inspected the installed
  `groundingdino-py==0.4.0` package (all `.py` files under the installed path) — it contains only inference code
  (`util/inference.py`, model/backbone/transformer modules) with **no** `matcher.py`, `criterion.py`, `loss.py`, or
  any training entrypoint. Fine-tuning would require pulling in the third-party `open-groundingdino` project as a
  new dependency, which was not approved. GroundingDINO is therefore downgraded to a zero-shot reference line only
  (not yet run) rather than a formal fine-tuning candidate.

## Evaluation

- Metric: `mAP50-95` (ultralytics native output from `results.csv`), `direction: maximize`, per `benchmark/references/cv.md` convention.
- Eval set: the dataset's own `val.txt` (1000 held-out images), consistent with `datasets/SKILL.md` no-leakage guidance (separate city/tile stems from train).

## Baseline results (final)

| model | params (M) | epochs (early-stopped) | mAP50 | mAP50-95 | training time |
|---|---|---|---|---|---|
| **yolo11x (selected)** | 56.9 | 136 | 0.7068 | **0.4422** | 5.00h |
| yolo26n | 2.5 | 329 (early-stopped @229) | 0.6441 | 0.3904 | 4.65h |

`yolo11x` wins on `mAP50-95` by a clear margin (+0.052) despite ~23x more parameters — selected as `base_model` for
the experiment loop. Per-class breakdown for `yolo11x`: weakest classes are Transverse Crack (0.358) and Pothole
(0.379, the rarest class at 4.4% of instances) — both flagged as Phase 2 targets. `baseline.value = 0.44222`,
commit `16e6a59`.

## Status

`status: looping` — Phase 1 complete, baseline established. See `improve_guide.md` for Phase 2 candidates and
`experiment_logs/cv-svrdd-detect-jul06/experiment_results.csv` for live Phase 3 loop progress.
