# mmdetection Adapter Notes

Config-driven detection/segmentation training framework covering a wide range of backbones, necks, and detection/segmentation heads.

## Editable

- The training config (`*_config.py`): backbone choice (among supported ones), neck, head, anchor settings, augmentation pipeline, LR schedule, batch size, number of epochs.
- Custom config overrides for a specific experiment (mmdetection configs are typically composed/inherited — add an override file rather than editing shared base configs in place).

## Read-only

- The core model registry/implementation code and the evaluation (COCO-eval style mAP computation) code.
- Shared base configs that other scenarios/experiments might also inherit from — always override in a scenario-specific config file, never edit the shared base directly.

## Launch convention

`scripts/mmdetection_run.sh <config.py> <time_budget_min>` should invoke mmdetection's training entrypoint (`tools/train.py`-style) with the config, and bound the run either via `max_epochs`/iteration-based settings tuned to roughly match the budget, or via an external wall-clock wrapper that allows the current epoch to checkpoint before stopping.

## Budget mapping

Epoch time is fairly predictable once the baseline run establishes seconds/epoch for a given backbone/resolution/batch-size combination — use that to set an approximate `max_epochs` for the config, but keep the external time wrapper as the actual authority since backbone/resolution changes shift epoch time significantly between experiments.

## Metric extraction

Parse the final mAP (and per-class AP if available) from the evaluation output at the end of training; map peak GPU memory to `peak_vram_mb`.

## Common pitfalls

- Changing input resolution changes both accuracy and epoch time substantially — treat it as a first-class experiment variable, not an incidental one.
- Anchor settings tuned for one dataset's object-size distribution may silently hurt mAP on a different dataset — re-check anchors when the scenario's data differs a lot in scale from the config's original target dataset.
