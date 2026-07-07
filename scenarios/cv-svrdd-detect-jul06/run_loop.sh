#!/usr/bin/env bash
# Phase 3 experiment-loop driver for cv-svrdd-detect-jul06.
# Implements the mechanics of skills/experiment-loop/SKILL.md: one variable at a
# time vs. the current best, fixed time budget, keep/discard, log, never stop.
#
# Usage: bash run_loop.sh
# Intended to be launched inside tmux (see scripts/SKILL.md convention) so it
# survives the driving session ending.

set -uo pipefail

SCEN_DIR="/home/dataset1/gaojing/uautoresearch/scenarios/cv-svrdd-detect-jul06"
REPO_DIR="/home/dataset1/gaojing/uautoresearch"
LOG_DIR="/home/dataset1/gaojing/uautoresearch/experiment_logs/cv-svrdd-detect-jul06"
RESULTS_CSV="$LOG_DIR/experiment_results.csv"
DATA_YAML="$SCEN_DIR/configs/data.yaml"
BASE_MODEL="/home/dataset1/gaojing/xibeiyuan/models/yolo11x/yolo11x.pt"
TIME_BUDGET_MIN=300
DEVICE=0
CHECKPOINT_ROOT="/home/dataset1/gaojing/xibeiyuan/checkpoints"

mkdir -p "$LOG_DIR"
if [[ ! -f "$RESULTS_CSV" ]]; then
    echo "commit,metric_value,peak_vram_gb,status,domain,engine,description" > "$RESULTS_CSV"
fi

CURRENT_BEST=0.44222  # yolo11x baseline, commit 16e6a59

# name : imgsz : batch : extra_args : description
CANDIDATES=(
    "imgsz960:960:14::imgsz 640->960 for thin/elongated crack classes"
    "no_mosaic:640:32:mosaic=0.0:disable mosaic augmentation (may fragment thin linear crack features)"
    "focal_loss:640:32:fl_gamma=1.5:focal loss (fl_gamma=1.5) to address class imbalance (Pothole 4.4%)"
    "cos_lr:640:32:cos_lr=True lr0=0.001:cosine LR schedule + lower initial LR for stabler fine-tuning"
    "copy_paste:640:32:copy_paste=0.3:copy-paste augmentation to boost rare-class (Pothole/Alligator) exposure"
    "no_geo_aug:640:32:degrees=0 shear=0 perspective=0:disable rotation/shear/perspective (orientation is class-defining)"
)

for entry in "${CANDIDATES[@]}"; do
    IFS=':' read -r NAME IMGSZ BATCH EXTRA_ARGS DESC <<< "$entry"
    RUN_DIR="$CHECKPOINT_ROOT/svrdd_yolo11x_${NAME}"
    CONFIG_FILE="$SCEN_DIR/configs/yolo11x_${NAME}.env"

    echo "=== [$(date -Iseconds)] starting candidate: $NAME ($DESC) ==="

    cat > "$CONFIG_FILE" <<EOF
DATA_YAML=$DATA_YAML
BASE_MODEL=$BASE_MODEL
IMGSZ=$IMGSZ
BATCH=$BATCH
EPOCHS=1000
DEVICE=$DEVICE
RUN_DIR=$RUN_DIR
EXTRA_ARGS=$EXTRA_ARGS
EOF

    cd "$REPO_DIR"
    git add "$CONFIG_FILE"
    git commit -m "experiment(cv-svrdd-detect-jul06): try $NAME - $DESC" -q
    COMMIT_HASH=$(git rev-parse --short=7 HEAD)

    bash scripts/ultralytics_run.sh "$CONFIG_FILE" "$TIME_BUDGET_MIN"
    RUN_STATUS=$?

    METRIC_LINE=$(grep "^metric_value:" "$RUN_DIR/run.log" 2>/dev/null | tail -1)
    VRAM_LINE=$(grep "^peak_vram_mb:" "$RUN_DIR/run.log" 2>/dev/null | tail -1)

    if [[ $RUN_STATUS -ne 0 || -z "$METRIC_LINE" ]]; then
        METRIC_VALUE="0.0"
        PEAK_VRAM_GB="0.0"
        STATUS="crash"
        echo "=== candidate $NAME CRASHED (status=$RUN_STATUS) ==="
        git reset --hard HEAD~1 -q
    else
        METRIC_VALUE=$(echo "$METRIC_LINE" | awk '{print $2}')
        PEAK_VRAM_MB=$(echo "$VRAM_LINE" | awk '{print $2}')
        PEAK_VRAM_GB=$(python3 -c "print(round(${PEAK_VRAM_MB:-0} / 1024, 1))")

        IS_BETTER=$(python3 -c "print(1 if float('$METRIC_VALUE') > float('$CURRENT_BEST') else 0)")
        if [[ "$IS_BETTER" == "1" ]]; then
            STATUS="keep"
            CURRENT_BEST="$METRIC_VALUE"
            echo "=== candidate $NAME KEEP (mAP50-95 $METRIC_VALUE > previous best) ==="
            python3 - "$SCEN_DIR/scenario.yaml" "$METRIC_VALUE" "$COMMIT_HASH" <<'PYEOF'
import sys, re
path, value, commit = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    text = f.read()
text = re.sub(r"(current_best:\n  value: )[^\n]*", rf"\g<1>{value}", text)
text = re.sub(r"(current_best:\n  value: [^\n]*\n  run_id: )[^\n]*", rf"\g<1>{commit}", text)
with open(path, "w") as f:
    f.write(text)
PYEOF
            git add "$SCEN_DIR/scenario.yaml"
            git commit -m "keep: $NAME improves mAP50-95 to $METRIC_VALUE" -q
        else
            STATUS="discard"
            echo "=== candidate $NAME DISCARD (mAP50-95 $METRIC_VALUE <= previous best $CURRENT_BEST) ==="
            git reset --hard HEAD~1 -q
        fi
    fi

    echo "$COMMIT_HASH,$METRIC_VALUE,$PEAK_VRAM_GB,$STATUS,cv,ultralytics,$NAME: $DESC" >> "$RESULTS_CSV"
    echo "=== [$(date -Iseconds)] finished candidate: $NAME -> status=$STATUS metric=$METRIC_VALUE (current_best=$CURRENT_BEST) ==="
done

echo "=== [$(date -Iseconds)] run_loop.sh: all Tier 0/1 candidates exhausted. current_best=$CURRENT_BEST ==="
echo "=== See $RESULTS_CSV and $SCEN_DIR/scenario.yaml for final state. Next: knowledge-update + final_report.md ==="
