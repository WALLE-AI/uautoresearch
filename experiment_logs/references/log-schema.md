# Log Schema Reference

## `run.log` universal fields (required, all domains)

| Field | Type | Meaning |
|---|---|---|
| `metric_name` | string | Must match `scenario.yaml`'s `metric.name` |
| `metric_value` | float | The achieved value for this run |
| `training_seconds` | float | Pure training wall-clock time (excludes startup/compilation) |
| `total_seconds` | float | Total wall-clock time including startup/eval overhead |
| `peak_vram_mb` | float | Peak GPU memory used, in MB |
| `num_params_M` | float | Model parameter count, in millions |

## Optional domain-specific fields

| Field | Domain | Meaning |
|---|---|---|
| `num_steps` | any | Total optimizer steps completed |
| `mfu_percent` | LLM/VLM | Model FLOPs utilization |
| `total_tokens_M` | LLM/VLM | Total tokens processed, in millions |
| `depth` / `width` | LLM/VLM | Architecture size knobs, if varied |
| `mAP50` / `mAP50_95` | CV detection | Additional detection-specific metrics beyond the primary `metric_value` |
| `mIoU` | CV segmentation | Additional segmentation-specific metric |
| `epoch` | CV/NLP | Final epoch reached |

Adding a new optional field is fine; never repurpose an existing field name for a different meaning between engines.

## `experiment_results.csv` column schema

| Column | Type | Notes |
|---|---|---|
| `commit` | string (7 chars) | Short git commit hash |
| `metric_value` | float | `0.0` for crashes |
| `peak_vram_gb` | float, 1 decimal | `peak_vram_mb / 1024`; `0.0` for crashes |
| `status` | enum | `keep` \| `discard` \| `crash` |
| `domain` | enum | `cv` \| `nlp` \| `llm` \| `vlm` |
| `engine` | string | `trainer_engine` value from `scenario.yaml` |
| `description` | string | Short, human-readable; avoid commas if using comma-separated format |

## Parsing tips

```bash
# Extract the two most important fields from a run.log
grep "^metric_value:\|^peak_vram_mb:" run.log

# Empty output from the above => the run crashed; investigate with:
tail -n 50 run.log
```
