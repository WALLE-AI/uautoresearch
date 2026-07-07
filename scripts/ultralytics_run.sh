#!/usr/bin/env bash
# Launch wrapper for the ultralytics trainer engine.
# See trainer/references/ultralytics.md for the full adapter contract.
#
# Usage:
#   scripts/ultralytics_run.sh <config> <time_budget_min>
#
# <config> is a shell-sourceable file defining:
#   DATA_YAML        absolute path to the ultralytics data.yaml
#   BASE_MODEL       absolute path to the .pt checkpoint to start from
#   IMGSZ            image size (default 640)
#   BATCH            batch size (default -1 = ultralytics auto-batch)
#   EPOCHS           upper bound on epochs (time budget is the real cutoff via `time=`)
#   DEVICE           GPU device string, e.g. "0" or "0,1,2,3,4,5,6,7" (default 0)
#   RUN_DIR          absolute path, must be unique per experiment iteration
#                    (holds ultralytics' native weights/results.csv artifacts)
#   LOG_DIR          absolute path, must be unique per experiment iteration
#                    (holds run.log; defaults to RUN_DIR if unset, for
#                    backward compat, but should be set to
#                    experiment_logs/<tag>/runs/<candidate> per
#                    experiment_logs/SKILL.md's centralized log convention)
#   EXTRA_ARGS       (optional) extra ultralytics CLI args, e.g. "lr0=0.001 mosaic=0.0"
#
# Writes run.log in LOG_DIR (falls back to RUN_DIR) with the six unified
# fields required by experiment_logs/SKILL.md.

set -uo pipefail

CONFIG="$1"
TIME_BUDGET_MIN="$2"

if [[ -z "$CONFIG" || -z "$TIME_BUDGET_MIN" ]]; then
    echo "Usage: $0 <config> <time_budget_min>" >&2
    exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG"

: "${DATA_YAML:?DATA_YAML must be set in config}"
: "${BASE_MODEL:?BASE_MODEL must be set in config}"
: "${RUN_DIR:?RUN_DIR must be set in config}"
IMGSZ="${IMGSZ:-640}"
BATCH="${BATCH:--1}"
EPOCHS="${EPOCHS:-1000}"
DEVICE="${DEVICE:-0}"
EXTRA_ARGS="${EXTRA_ARGS:-}"
LOG_DIR="${LOG_DIR:-$RUN_DIR}"

mkdir -p "$RUN_DIR" "$LOG_DIR"
LOG_FILE="$LOG_DIR/run.log"
TIME_HOURS=$(python3 -c "print(${TIME_BUDGET_MIN} / 60.0)")

START_TS=$(date +%s)

VRAM_POLL_FILE=$(mktemp)
FIRST_GPU="${DEVICE%%,*}"
(
    MAX_MB=0
    while true; do
        CUR_MB=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits -i "$FIRST_GPU" 2>/dev/null | head -1)
        if [[ -n "$CUR_MB" && "$CUR_MB" =~ ^[0-9]+$ && "$CUR_MB" -gt "$MAX_MB" ]]; then
            MAX_MB="$CUR_MB"
            echo "$MAX_MB" > "$VRAM_POLL_FILE"
        fi
        sleep 5
    done
) &
VRAM_POLL_PID=$!

{
    echo "=== ultralytics_run.sh starting $(date -Iseconds) ==="
    echo "config: $CONFIG"
    echo "data_yaml: $DATA_YAML"
    echo "base_model: $BASE_MODEL"
    echo "run_dir: $RUN_DIR"
    echo "imgsz: $IMGSZ  batch: $BATCH  epochs: $EPOCHS  device: $DEVICE  time_budget_min: $TIME_BUDGET_MIN"

    yolo detect train \
        data="$DATA_YAML" \
        model="$BASE_MODEL" \
        imgsz="$IMGSZ" \
        batch="$BATCH" \
        epochs="$EPOCHS" \
        time="$TIME_HOURS" \
        device="$DEVICE" \
        project="$RUN_DIR" \
        name="train" \
        exist_ok=True \
        $EXTRA_ARGS
    STATUS=$?

    kill "$VRAM_POLL_PID" 2>/dev/null
    wait "$VRAM_POLL_PID" 2>/dev/null
    PEAK_VRAM_MB=$(cat "$VRAM_POLL_FILE" 2>/dev/null || echo 0)
    rm -f "$VRAM_POLL_FILE"

    END_TS=$(date +%s)
    TOTAL_SECONDS=$((END_TS - START_TS))

    echo "=== ultralytics train exited with status $STATUS ==="

    RESULTS_CSV="$RUN_DIR/train/results.csv"
    if [[ $STATUS -eq 0 && -f "$RESULTS_CSV" ]]; then
        python3 - "$RESULTS_CSV" "$RUN_DIR/train/weights/best.pt" "$TOTAL_SECONDS" "$PEAK_VRAM_MB" <<'PYEOF'
import csv, sys, torch, os

results_csv, best_pt, total_seconds, peak_vram_mb_arg = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

with open(results_csv) as f:
    rows = list(csv.DictReader(f))

last = rows[-1]

def find_col(row, keyword):
    for k in row:
        if keyword in k:
            return k
    return None

map5095_col = find_col(last, "metrics/mAP50-95")
map50_col = find_col(last, "metrics/mAP50(B)") or find_col(last, "metrics/mAP50")
epoch_time_col = find_col(last, "time")

map5095 = float(last[map5095_col]) if map5095_col else float("nan")
map50 = float(last[map50_col]) if map50_col else float("nan")
training_seconds = float(last[epoch_time_col]) if epoch_time_col else float(total_seconds)

num_params_m = float("nan")
if os.path.exists(best_pt):
    ckpt = torch.load(best_pt, map_location="cpu", weights_only=False)
    model = ckpt.get("model")
    if model is not None:
        num_params_m = sum(p.numel() for p in model.parameters()) / 1e6

peak_vram_mb = float(peak_vram_mb_arg) if peak_vram_mb_arg else float("nan")

print(f"metric_name: mAP50-95")
print(f"metric_value: {map5095}")
print(f"mAP50: {map50}")
print(f"training_seconds: {training_seconds}")
print(f"total_seconds: {total_seconds}")
print(f"peak_vram_mb: {peak_vram_mb}")
print(f"num_params_M: {num_params_m}")
PYEOF
    else
        echo "metric_name: mAP50-95"
        echo "metric_value: 0.0"
        echo "training_seconds: 0.0"
        echo "total_seconds: $TOTAL_SECONDS"
        echo "peak_vram_mb: $PEAK_VRAM_MB"
        echo "num_params_M: 0.0"
        echo "CRASH: ultralytics training did not produce results.csv (status=$STATUS)"
    fi
} >> "$LOG_FILE" 2>&1

exit $STATUS
