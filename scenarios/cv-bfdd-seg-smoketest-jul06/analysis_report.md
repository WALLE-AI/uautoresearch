# Phase 1: Scenario Analysis — cv-bfdd-seg-smoketest-jul06

**Purpose of this scenario**: feasibility smoke test of the uautoresearch Markdown-agent loop, not real research. Run 1-2 loop iterations to confirm the framework can actually drive an external, pre-existing training codebase end-to-end (edit config → launch → extract metric → keep/discard → log), then stop and report to the user. Do not chase beating the existing best result.

## Domain and task type

CV — semantic segmentation. 6 classes (background + Crack, Spalling, Delamination, [4th defect type], Stain — see `src/dataset_bfdd.py` for exact label mapping). Input is RGB+IR fusion (4-channel), not plain RGB.

## 7-dimension diagnosis

- **Base model suitability**: `swin_base_patch4_window12_384.ms_in22k_ft_in1k` is a proven fit — the existing `xibeiyuan` project already reached val_mIoU=59.97% fine-tuning this exact encoder via `train_bfdd_swin.py` + SMP MAnet decoder. No change needed for this smoke test.
- **Data quality**: already vetted by prior work in `xibeiyuan` (686 stems in `train.txt`, deterministic 85/15 train/val split, per-class pixel weighting for imbalance, copy-paste augmentation for rare classes). Not re-analyzed here.
- **Prompt/task formulation**: n/a (CV, not LLM/VLM).
- **Training method fit**: fine-tuning (`--finetune` from an existing checkpoint) is the correct and fast method for a smoke test — avoids paying for a from-scratch warm-up.
- **Evaluation soundness**: `ConfusionMatrix.get_metrics()` in `train_bfdd_swin.py` computes pixel accuracy, mIoU, and per-class IoU/F1 on the held-out val split — sound, already used to produce the 59.97% baseline number.
- **Baseline history**: `knowledge/` has no prior entry for this project (checked before writing this report). This smoke test's `knowledge/experience/cv.md` write-back (Phase 4) will be the first entry.
- **Compute/hardware fit**: 8× A100 40GB. Empirically ~16s/epoch at 1024×1024 with batch=2/GPU (see `xibeiyuan/logs/*.log`), so a 12-minute budget fits 40+ epochs comfortably — no OOM risk expected at the existing batch size.

## Dataset EDA

Delegated conceptually to `datasets/SKILL.md`, but **not re-run in depth** for this smoke test since the dataset is already fully characterized by the existing `xibeiyuan` project (686 stems, 6 classes, RGB+IR+Label triplets under `datasets/facade_defect_detection/BFDD_Dataset/`). Registering here for reference only, not re-deriving.

## Baseline model selection

Reuse `xibeiyuan/checkpoints/bfdd_swin_base_ft/best.pth` (val_mIoU=0.5997) as both `baseline.run_id` and the `--pretrain_ckpt` every loop iteration fine-tunes from. **No baseline run needs to be executed for this scenario** — it already exists.

## Trainer engine

`custom-bfdd-segmentation` (new one-off adapter, see `trainer/references/custom-bfdd-segmentation.md`) — none of the 6 standard engines match this bespoke DDP script.

## Notes

This scenario intentionally skips the normal Phase 1 rigor (no fresh EDA, no baseline run, no from-scratch model comparison) because its purpose is to validate the *framework's* mechanics, not to do original research on this dataset. `improve_guide.md` (Phase 2) should likewise propose only trivial, low-risk single-variable experiments.
