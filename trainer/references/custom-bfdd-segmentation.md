# custom-bfdd-segmentation Adapter Notes

A one-off adapter for an existing bespoke PyTorch DDP training script, used when a scenario's codebase does not match any of the six standard engines in `trainer/SKILL.md`. This is the reference implementation of the "custom engine" pattern — copy this structure for other bespoke research scripts.

**Underlying code** (external to `uautoresearch`, never copied in): `xibeiyuan/train_bfdd_swin.py`, launched via `xibeiyuan/.venv/bin/torchrun`. Task: 6-class (background + 5 defect types) semantic segmentation on RGB+IR fused facade imagery, Swin encoder + SMP MAnet decoder.

## Editable

- CLI hyperparameters: `--lr`, `--batch_size`, `--accumulate`, `--epochs`, `--early_stop`, `--encoder_name` (`swin_small`/`swin_base`/`swin_large`), `--loss_type`, `--tversky_beta_overrides`, `--ir_attention`, `--mosaic_prob`, `--rare_class_oversample`, `--model_type`.
- `--checkpoint_dir` per experiment (must be unique per run so checkpoints don't clobber each other).

## Read-only

- `src/dataset_bfdd.py`, `src/losses.py`, `ConfusionMatrix`/`validate()` in `train_bfdd_swin.py` (data loading and metric computation).
- `TRAIN_TXT`/`RGB_DIR`/`IR_DIR`/`LABEL_DIR` module-level constants — these are hardcoded paths, not CLI args. Do not edit the script to change them; if a scenario genuinely needs a different data split, surface it to the human instead of patching this file.
- Existing checkpoints under `xibeiyuan/checkpoints/` other than the one this scenario is writing to.

## Launch convention

`scripts/custom-bfdd-segmentation_run.sh <config> <time_budget_min>`

`<config>` is a shell-sourceable file (or inline env vars) providing the editable hyperparameters above plus `CHECKPOINT_DIR`. The wrapper `cd`s into `xibeiyuan/`, activates nothing (uses `.venv/bin/torchrun` directly), and runs:

```bash
HF_HUB_OFFLINE=1 PYTHONPATH=. timeout "${TIMEOUT_SECONDS}" .venv/bin/torchrun \
    --standalone --nproc_per_node=8 \
    train_bfdd_swin.py \
    --encoder_name "$ENCODER_NAME" --batch_size "$BATCH_SIZE" --accumulate "$ACCUMULATE" \
    --epochs "$EPOCHS" --lr "$LR" --early_stop "$EARLY_STOP" \
    --checkpoint_dir "$CHECKPOINT_DIR" \
    --pretrain_ckpt "$PRETRAIN_CKPT" --finetune
```

## Budget mapping

No native wall-clock flag. Empirically **~16s/epoch** on 8×A100 40GB at the default 1024×1024 resolution with the full 686-stem BFDD split (measured from `xibeiyuan/logs/*.log`), so a 10-15 min budget comfortably fits 30-50+ epochs — set `--epochs` generously (e.g. 40) and let the external `timeout` wrapper be the real cutoff; a checkpoint is only overwritten on a new best mIoU, so `timeout`'s SIGTERM is safe (worst case: loses the in-progress epoch, keeps the last saved best).

## Metric extraction

Script prints, once per epoch on rank 0:

```
Epoch 02/40 | Train Loss: 1.4465 | Val Loss: 1.5957 | Pixel Acc: 0.9369 | mIoU: 0.5343 | F1 Score: 0.6594 | Time: 15.8s
```

and on new best:

```
  --> Saved NEW BEST checkpoint (mIoU=0.5343) to <path>
```

The wrapper must, after the process exits, parse the **last** `mIoU:` value from `run.log` and append the six unified fields (`metric_name: val_mIoU`, `metric_value`, `training_seconds` = sum of per-epoch `Time:` values, `total_seconds` = wall-clock of the whole invocation, `peak_vram_mb` via `torch.cuda.max_memory_allocated()` — not natively printed, so poll `nvidia-smi --query-gpu=memory.used` during the run or add a one-line print at script exit if editing is acceptable — and `num_params_M`, computed once from the checkpoint's `state_dict` param count).

## Common pitfalls

- `--finetune` resets `best_mIoU` to 0 and drops the optimizer/scheduler state, so every finetune run's first-epoch mIoU is not comparable to a from-scratch run's — always finetune from the same `--pretrain_ckpt` baseline for a given scenario's comparisons.
- The script only saves a checkpoint on a **new best** epoch; if a smoke-test run's budget expires before any epoch beats `best_mIoU` (unlikely given epochs reset to 0 baseline under `--finetune`, since epoch 1 is very likely a new best from the previous best_mIoU), no `best.pth` file will appear in the fresh `--checkpoint_dir` — this is expected, not a crash.
- `--checkpoint_dir` must be unique per experiment iteration or checkpoints from different loop iterations will silently overwrite each other.
