#!/usr/bin/env bash
# Phase 3 experiment-loop driver (parallel mode) for cv-svrdd-detect-jul06,
# rebuilt on scripts/loop_driver_template.sh per the new multi-agent design
# (AGENTS.md role table). Key difference from the old run_loop_parallel.sh:
# EACH candidate gets its own commit and its own independent keep/discard
# (git revert), never a single batch commit for all N candidates.
#
# Roles (see skills/experiment-loop/SKILL.md "Parallel mode"):
#   [Trainer Agent]   writes configs, launches runs
#   [Monitor Agent]   polls loss/metric/GPU while each run is in progress,
#                      writes monitor.log/metrics.csv (monitor/SKILL.md)
#   [Git-Ops Agent]   commits/reverts/updates scenario.yaml, appends ledger
#   [Evaluator Agent] extracts metric_value/peak_vram_mb from each run.log
#
# run.log/monitor.log/metrics.csv all live under
# experiment_logs/cv-svrdd-detect-jul06/runs/<candidate>/ per
# experiment_logs/SKILL.md's centralized log-location convention.
#
# Usage: bash run_loop_v2.sh

set -uo pipefail

SCEN_DIR="/home/dataset1/gaojing/uautoresearch/scenarios/cv-svrdd-detect-jul06"
REPO_DIR="/home/dataset1/gaojing/uautoresearch"
LOG_DIR="/home/dataset1/gaojing/uautoresearch/experiment_logs/cv-svrdd-detect-jul06"
RESULTS_CSV="$LOG_DIR/experiment_results.csv"
RUNS_DIR="$LOG_DIR/runs"
MONITOR_INTERVAL_SEC=300
DATA_YAML="$SCEN_DIR/configs/data.yaml"
BASE_MODEL="/home/dataset1/gaojing/xibeiyuan/models/yolo11x/yolo11x.pt"
TIME_BUDGET_MIN=300
CHECKPOINT_ROOT="/home/dataset1/gaojing/xibeiyuan/checkpoints"
BASELINE_BEST=0.44222
METRIC_DIRECTION="maximize"
DOMAIN="cv"
ENGINE="ultralytics"

# name : imgsz : batch : device : extra_args : description
CANDIDATES=(
    "imgsz960:960:14:0::imgsz 640->960 for thin/elongated crack classes"
    "no_mosaic:640:32:1:mosaic=0.0:disable mosaic augmentation (may fragment thin linear crack features)"
    "focal_loss:640:32:2:fl_gamma=1.5:focal loss (fl_gamma=1.5) to address class imbalance (Pothole 4.4%)"
    "cos_lr:640:32:3:cos_lr=True lr0=0.001:cosine LR schedule + lower initial LR for stabler fine-tuning"
    "copy_paste:640:32:4:copy_paste=0.3:copy-paste augmentation to boost rare-class (Pothole/Alligator) exposure"
    "no_geo_aug:640:32:5:degrees=0 shear=0 perspective=0:disable rotation/shear/perspective (orientation is class-defining)"
)

mkdir -p "$LOG_DIR" "$RUNS_DIR"
if [[ ! -f "$RESULTS_CSV" ]]; then
    echo "commit,metric_value,peak_vram_gb,status,domain,engine,description" > "$RESULTS_CSV"
fi

# --- [Monitor Agent] poller: one per candidate, backgrounded, independent
# of the Trainer Agent's wait. See monitor/SKILL.md for the full contract.
poll_candidate() {
    local name="$1" device="$2" run_log_dir="$3" results_csv_native="$4"
    local metrics_csv="$run_log_dir/metrics.csv" monitor_log="$run_log_dir/monitor.log"
    echo "timestamp,loss,metric_value,gpu_util,gpu_mem_mb" > "$metrics_csv"
    local zero_streak=0
    while true; do
        if [[ -f "$run_log_dir/run.log" ]] && grep -q "^metric_value:" "$run_log_dir/run.log" 2>/dev/null; then
            break
        fi
        local ts loss metric gpu_util gpu_mem
        ts=$(date -Iseconds)
        if [[ -f "$results_csv_native" ]]; then
            loss=$(tail -1 "$results_csv_native" | awk -F, '{print $3}')
            metric=$(tail -1 "$results_csv_native" | awk -F, '{print $7}')
        else
            loss=""; metric=""
        fi
        read -r gpu_util gpu_mem <<< "$(nvidia-smi --query-gpu=utilization.gpu,memory.used --format=csv,noheader,nounits -i "$device" 2>/dev/null | tr ',' ' ')"
        echo "$ts,$loss,$metric,$gpu_util,$gpu_mem" >> "$metrics_csv"
        echo "[$ts] $name: loss=$loss metric=$metric gpu_util=${gpu_util}% gpu_mem=${gpu_mem}MB" >> "$monitor_log"
        if [[ "$loss" == "nan" || "$loss" == "inf" ]]; then
            echo "[ALERT] loss=$loss at $ts" >> "$monitor_log"
        fi
        if [[ "$gpu_util" == "0" ]]; then
            zero_streak=$((zero_streak + 1))
            [[ "$zero_streak" -eq 3 ]] && echo "[ALERT] gpu_util=0 for 3 consecutive polls, possible hang" >> "$monitor_log"
        else
            zero_streak=0
        fi
        sleep "$MONITOR_INTERVAL_SEC"
    done
}

cd "$REPO_DIR"

# --- [Git-Ops Agent] Step 1: one commit PER candidate, never batched ------
echo "=== [$(date -Iseconds)] [Git-Ops Agent] committing ${#CANDIDATES[@]} candidate configs (one commit each) ==="
declare -A CANDIDATE_COMMIT
declare -A CANDIDATE_RUNDIR
declare -A CANDIDATE_LOGDIR
declare -A CANDIDATE_NATIVE_CSV
for entry in "${CANDIDATES[@]}"; do
    IFS=':' read -r NAME IMGSZ BATCH DEVICE EXTRA_ARGS DESC <<< "$entry"
    CONFIG_FILE="$SCEN_DIR/configs/yolo11x_${NAME}_v2.env"
    RUN_DIR="$CHECKPOINT_ROOT/svrdd_yolo11x_${NAME}_v2"
    RUN_LOG_DIR="$RUNS_DIR/$NAME"
    mkdir -p "$RUN_LOG_DIR"
    CANDIDATE_RUNDIR["$NAME"]="$RUN_DIR"
    CANDIDATE_LOGDIR["$NAME"]="$RUN_LOG_DIR"
    CANDIDATE_NATIVE_CSV["$NAME"]="$RUN_DIR/train/results.csv"
    cat > "$CONFIG_FILE" <<EOF
DATA_YAML=$DATA_YAML
BASE_MODEL=$BASE_MODEL
IMGSZ=$IMGSZ
BATCH=$BATCH
EPOCHS=1000
DEVICE=$DEVICE
RUN_DIR=$RUN_DIR
LOG_DIR=$RUN_LOG_DIR
EXTRA_ARGS=$EXTRA_ARGS
EOF
    git add "$CONFIG_FILE"
    if git diff --cached --quiet -- "$CONFIG_FILE"; then
        git reset -q -- "$CONFIG_FILE"
        CANDIDATE_COMMIT["$NAME"]=$(git log -1 --format=%h -- "$CONFIG_FILE")
        echo "  [Git-Ops Agent] $NAME config unchanged, reusing commit ${CANDIDATE_COMMIT[$NAME]}"
    else
        git commit -m "fix(cv-svrdd-detect-jul06): candidate $NAME use centralized LOG_DIR for Monitor Agent" -q
        CANDIDATE_COMMIT["$NAME"]=$(git rev-parse --short=7 HEAD)
        echo "  [Git-Ops Agent] committed $NAME -> ${CANDIDATE_COMMIT[$NAME]}"
    fi
done

# --- [Trainer Agent] Step 2: launch all candidates concurrently ----------
echo "=== [$(date -Iseconds)] [Trainer Agent] launching ${#CANDIDATES[@]} runs in parallel (one GPU each) ==="
PIDS=()
MONITOR_PIDS=()
for entry in "${CANDIDATES[@]}"; do
    IFS=':' read -r NAME IMGSZ BATCH DEVICE EXTRA_ARGS DESC <<< "$entry"
    CONFIG_FILE="$SCEN_DIR/configs/yolo11x_${NAME}_v2.env"
    bash scripts/ultralytics_run.sh "$CONFIG_FILE" "$TIME_BUDGET_MIN" &
    PIDS+=("$!")
    echo "  [Trainer Agent] launched $NAME on device $DEVICE (pid $!)"
    poll_candidate "$NAME" "$DEVICE" "${CANDIDATE_LOGDIR[$NAME]}" "${CANDIDATE_NATIVE_CSV[$NAME]}" &
    MONITOR_PIDS+=("$!")
    echo "  [Monitor Agent] polling $NAME every ${MONITOR_INTERVAL_SEC}s -> ${CANDIDATE_LOGDIR[$NAME]}/{monitor.log,metrics.csv}"
done

echo "=== [$(date -Iseconds)] [Trainer Agent] waiting for all ${#PIDS[@]} runs to finish (budget ${TIME_BUDGET_MIN}min) ==="
for pid in "${PIDS[@]}"; do
    wait "$pid"
done
for mpid in "${MONITOR_PIDS[@]}"; do
    kill "$mpid" 2>/dev/null
done
echo "=== [$(date -Iseconds)] all parallel runs finished, handing off to Evaluator/Git-Ops Agents ==="

# --- [Evaluator Agent] + [Git-Ops Agent] Step 3: per-candidate keep/discard
CURRENT_BEST="$BASELINE_BEST"
BEST_NAME="baseline"
for entry in "${CANDIDATES[@]}"; do
    IFS=':' read -r NAME IMGSZ BATCH DEVICE EXTRA_ARGS DESC <<< "$entry"
    COMMIT="${CANDIDATE_COMMIT[$NAME]}"
    RUN_LOG="${CANDIDATE_LOGDIR[$NAME]}/run.log"

    METRIC_LINE=$(grep "^metric_value:" "$RUN_LOG" 2>/dev/null | tail -1)
    VRAM_LINE=$(grep "^peak_vram_mb:" "$RUN_LOG" 2>/dev/null | tail -1)

    if [[ -z "$METRIC_LINE" ]]; then
        METRIC_VALUE="0.0"
        PEAK_VRAM_GB="0.0"
        STATUS="crash"
    else
        METRIC_VALUE=$(echo "$METRIC_LINE" | awk '{print $2}')
        PEAK_VRAM_MB=$(echo "$VRAM_LINE" | awk '{print $2}')
        PEAK_VRAM_GB=$(python3 -c "print(round(${PEAK_VRAM_MB:-0} / 1024, 1))")
        IS_BETTER=$(python3 -c "print(1 if float('$METRIC_VALUE') > float('$CURRENT_BEST') else 0)")
        if [[ "$IS_BETTER" == "1" ]]; then
            STATUS="keep"
        else
            STATUS="discard"
        fi
    fi

    echo "[Evaluator Agent] $NAME -> metric=$METRIC_VALUE status=$STATUS (commit $COMMIT)"
    echo "$COMMIT,$METRIC_VALUE,$PEAK_VRAM_GB,$STATUS,$DOMAIN,$ENGINE,$NAME: $DESC" >> "$RESULTS_CSV"

    if [[ "$STATUS" == "keep" ]]; then
        CURRENT_BEST="$METRIC_VALUE"
        BEST_NAME="$NAME"
        echo "[Git-Ops Agent] $NAME kept as new best (commit $COMMIT stays on branch)"
    elif [[ "$STATUS" == "discard" ]]; then
        git revert --no-edit "$COMMIT" -q && \
            echo "[Git-Ops Agent] $NAME discarded, reverted commit $COMMIT independently" || \
            echo "[Git-Ops Agent] WARNING: manual revert needed for $COMMIT ($NAME)"
    else
        echo "[Git-Ops Agent] $NAME crashed, commit $COMMIT left in history (config change itself is harmless), not reverted"
    fi
done

# --- [Git-Ops Agent] Step 4: update scenario.yaml if there's a new best ---
if [[ "$BEST_NAME" != "baseline" ]]; then
    echo "=== [$(date -Iseconds)] [Git-Ops Agent] new overall best: $BEST_NAME (mAP50-95=$CURRENT_BEST) ==="
    python3 - "$SCEN_DIR/scenario.yaml" "$CURRENT_BEST" "${CANDIDATE_COMMIT[$BEST_NAME]}" <<'PYEOF'
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
    git commit -m "keep: $BEST_NAME is new best, mAP50-95=$CURRENT_BEST (commit ${CANDIDATE_COMMIT[$BEST_NAME]})" -q
else
    echo "=== [$(date -Iseconds)] no candidate beat baseline ($BASELINE_BEST); current_best unchanged ==="
fi

echo "=== [$(date -Iseconds)] Tier 0/1 parallel batch complete (new multi-agent design). Results: ==="
cat "$RESULTS_CSV"
echo "=== Next: [Orchestrator] hand off to Knowledge-Update Agent (skills/knowledge-update/SKILL.md) if this was the last tier ==="
