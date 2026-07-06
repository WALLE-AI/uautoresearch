# Cost & Hardware Experience Log

## 8x A100 40GB — custom-bfdd-segmentation (swin_base, 1024x1024, batch=2/GPU, accumulate=4) — from scenario `cv-bfdd-seg-smoketest-jul06`, jul06

- ~10-16s/epoch, ~17GB peak VRAM per run. Startup overhead (dataset indexing, class-weight estimation, copy-paste pool pre-build across all 8 DDP ranks) adds ~60-90s before the first epoch completes — budget at least 3 minutes per experiment run for this codebase, ideally more.
