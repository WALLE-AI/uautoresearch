# CV Evaluation Reference

## Metrics

| Task | Metric | Direction |
|---|---|---|
| Image classification | top-1 / top-5 accuracy | maximize |
| Object detection | mAP (COCO-style, IoU 0.5:0.95) | maximize |
| Semantic segmentation | mIoU | maximize |
| Instance segmentation | mask mAP | maximize |
| Pose estimation | AP (OKS-based) | maximize |

## Public benchmark pointers

- Classification: ImageNet-1k (full-scale), CIFAR-10/100 (fast iteration).
- Detection/segmentation: COCO, Pascal VOC, Cityscapes (segmentation-specific).
- If the scenario is domain-specific (e.g. medical imaging, industrial defect detection), prefer a held-out split of the scenario's own data over a generic public benchmark — generic benchmarks may not reflect the target distribution at all.

## Evaluation harness boundary

The eval script that computes mAP/mIoU/accuracy (from the trainer engine — see `trainer/references/mmdetection.md` or `trainer/references/ultralytics.md`) is read-only during Phase 3. Only training config (augmentation, LR schedule, backbone choice within the engine's supported set, etc.) is editable.

## Notes

- For small/imbalanced datasets, report per-class metrics in `analysis_report.md`, not just the aggregate — an improving mAP can hide a regressing minority class.
- Keep the eval set fixed across all experiments in a scenario's loop; changing the eval set mid-loop invalidates keep/discard comparisons.
