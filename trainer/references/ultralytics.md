# ultralytics Adapter Notes

Fast-iteration detection (and segmentation/classification/pose) training framework (YOLO family), favored when quick experiment turnaround matters more than covering every possible architecture.

## Editable

- The training config/CLI args: model variant/size, image size, batch size, epochs, augmentation settings (mosaic, mixup, etc.), optimizer/LR schedule, dataset YAML (paths and class names).

## Read-only

- The core model implementation and built-in validation/metric computation code.
- Pretrained weights provenance — don't silently swap the base pretrained checkpoint without recording it as a Tier-1 (architecture) change in `improve_guide.md`.

## Launch convention

`scripts/ultralytics_run.sh <config> <time_budget_min>` should invoke the ultralytics training entrypoint (CLI or Python API) with the given args/config, bounding time via `epochs`/`time` argument if the installed version supports a native time-based stop, or via an external wall-clock wrapper otherwise.

## Budget mapping

Ultralytics exposes a native `time=<hours>` training argument in recent versions — prefer this over estimating epochs when available, since it directly matches the fixed-time-budget philosophy of this framework. Fall back to epoch-based estimation only if the installed version lacks it.

## Metric extraction

Parse mAP50 / mAP50-95 (and class-wise metrics if needed) from the results output at the end of training; ultralytics also reports peak memory usage which maps directly to `peak_vram_mb`.

## Common pitfalls

- Very short time budgets can end training before the LR schedule has properly annealed, making early experiments look artificially worse than they would with more time — keep this in mind when interpreting keep/discard decisions on the very first few runs of a new scenario, and consider a slightly longer budget for the baseline run specifically if needed.
- Mosaic/mixup augmentation defaults are tuned for large datasets — disable or reduce them for small datasets, otherwise they can dominate training and mask the effect of other changes being tested.
