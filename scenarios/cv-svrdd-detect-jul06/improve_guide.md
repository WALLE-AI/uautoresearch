# Phase 2 Improve Guide: SVRDD Road Distress Detection

Baseline: `yolo11x`, `mAP50-95 = 0.44222` (commit `16e6a59`). All candidates below change exactly one variable
relative to the **current best** config at the time they are tried (per `skills/experiment-loop/SKILL.md`).
`time_budget_min` is fixed at 300 (5h) for every run, per `scenario.yaml`.

Weakest classes from the baseline: Transverse Crack (mAP50-95 0.358, thin/low-contrast) and Pothole (0.379,
rarest class at 4.4% of instances) — candidates are chosen with these two failure modes in mind.

## Tier 0 — hyperparameter/training-strategy (cheap, single-variable, editable per `trainer/references/ultralytics.md`)

1. **`imgsz` 640 -> 960**. Higher resolution should help thin/elongated crack classes (Transverse/Longitudinal
   Crack) that lose signal at 640px. Reduce `batch` to fit VRAM (32 -> ~14 at 960px on a 40GB A100 for yolo11x).
2. **`mosaic=0.0`** (disable mosaic augmentation). Mosaic can fragment thin linear crack features across tile
   boundaries; for a dataset this size (6000 train images) it may be net-negative for this task even though
   ultralytics defaults assume it helps on larger datasets.
3. **`fl_gamma=1.5`** (enable focal loss on the classification head). Directly targets class imbalance
   (Pothole at 4.4% of instances) without touching read-only loss/eval code — this is a supported ultralytics
   CLI hyperparameter, not a code change.
4. **`cos_lr=True`, `lr0=0.001`** (cosine LR schedule, lower initial LR). Baseline used ultralytics defaults
   (linear decay, `lr0=0.01`); a lower LR with cosine annealing often improves convergence stability for
   fine-tuning pretrained detection backbones on a small (6000-image) dataset.

## Tier 1 — data augmentation (cheap, single-variable)

5. **`copy_paste=0.3`** (enable copy-paste augmentation). Directly increases effective sample count for rare
   classes (Pothole, Alligator Crack) by pasting instances across images — orthogonal to Tier 0 hyperparameter
   changes, try after individual Tier 0 wins are validated.
6. **`degrees=0, shear=0, perspective=0`** (disable rotation/shear/perspective). Road distress orientation
   (longitudinal vs transverse) is class-defining information — aggressive geometric augmentation may actively
   hurt by blurring the longitudinal/transverse distinction. Worth an isolated test.

## Tier 2 — architecture (high cost, out of automated-loop scope for now)

- **RT-DETR** (`rtdetr_v2_r18vd`, per `analysis_report.md`): only pursue if Tier 0/1 plateau. Requires confirming
  ultralytics' native RT-DETR support (`yolo detect train model=rtdetr-l.pt` style) or writing a new
  `trainer/references/custom-rtdetr.md` adapter if the local `rtdetr_v2_r18vd` checkpoint isn't ultralytics-native.
  Not started — flag to human before committing engineering time here.
- **GroundingDINO zero-shot reference** (not fine-tuned, ruled out per `analysis_report.md`): optional one-off
  eval for context, not part of the keep/discard loop since it's not comparably trained.

## Data-dimension fallback (if Tier 0/1/2 all plateau)

- Re-examine Pothole and Transverse Crack failure cases via `datasets/SKILL.md` (confusion matrix, visualize
  worst predictions) — may indicate label noise rather than a model/hyperparameter limitation, in which case
  surface to the human rather than continuing to burn budget on training changes.

## Execution order

Tier 0 items 1-4 run first, sequentially, each building on the best-so-far config (`current_best` in
`scenario.yaml`). Tier 1 items run next if Tier 0 yields at least one `keep`. Driven by
`scenarios/cv-svrdd-detect-jul06/run_loop.sh` (see Phase 3).
