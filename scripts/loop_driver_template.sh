#!/usr/bin/env bash
# Generic parallel experiment-loop driver template (Phase 3, parallel mode).
#
# Copy this into scenarios/<tag>/ and fill in the CONFIG section below.
# Implements the pattern from skills/experiment-loop/SKILL.md's "Parallel
# mode" section: N mutually-independent single-variable candidates from
# improve_guide.md, launched one per idle GPU via scripts/<engine>_run.sh,
# with EACH candidate given its OWN config file (copied from current_best,
# never edited in place) and kept/discarded INDEPENDENTLY. There is no git
# commit/revert step anywhere in this framework.
#
# Also starts one Monitor Agent poller per candidate (monitor/SKILL.md),
# writing monitor.log/metrics.csv alongside run.log for real-time health
# visibility while the runs are in progress.
#
# Usage: bash loop_driver_template.sh

set -uo pipefail

# ============================== CONFIG ======================================
SCEN_DIR="/path/to/scenarios/<tag>"
REPO_DIR="/path/to/uautoresearch"
LOG_DIR="/path/to/experiment_logs/<tag>"
RESULTS_CSV="$LOG_DIR/experiment_results.csv"
ENGINE="ultralytics"                 # matches trainer_engine in scenario.yaml
RUN_SCRIPT="scripts/${ENGINE}_run.sh"
TIME_BUDGET_MIN=300
BASELINE_BEST=0.0                    # current_best.value from scenario.yaml
BASELINE_CONFIG="$SCEN_DIR/configs/baseline.cfg"  # current_best.config_path
METRIC_DIRECTION="maximize"          # maximize | minimize, from scenario.yaml
DOMAIN="cv"                          # from scenario.yaml

# name : config_template_fn_args (engine-specific) : description
# Each candidate must produce its own config file consumed by RUN_SCRIPT and
# its own RUN_DIR so run.log files never collide. Adjust the format of each
# candidate entry and the config-writing loop below to match your engine's
# config convention (env file, yaml, CLI args file, etc).
CANDIDATES=(
    # "name:extra_field1:extra_field2:...:description"
)

# Centralized log dir per candidate (run.log + Monitor Agent's monitor.log/
# metrics.csv). Engine-specific RUN_DIR (weights/native results) is separate.
RUNS_DIR="$LOG_DIR/runs"
MONITOR_INTERVAL_SEC=300
# =============================================================================

mkdir -p "$LOG_DIR" "$RUNS_DIR" "$SCEN_DIR/configs"
if [[ ! -f "$RESULTS_CSV" ]]; then
    echo "candidate,config_path,metric_value,peak_vram_gb,status,domain,engine,description" > "$RESULTS_CSV"
fi

# --- [Monitor Agent] poller: one per candidate, backgrounded, independent
# of the Trainer Agent's wait. See monitor/SKILL.md for the full contract.
# Engine-specific: fill in how to read the latest loss/metric for $NAME
# (e.g. tail its native results.csv) where marked below.
poll_candidate() {
    local name="$1" device="$2" run_log_dir="$3"
    local metrics_csv="$run_log_dir/metrics.csv" monitor_log="$run_log_dir/monitor.log"
    echo "timestamp,loss,metric_value,gpu_util,gpu_mem_mb" > "$metrics_csv"
    local zero_streak=0
    while true; do
        if [[ -f "$run_log_dir/run.log" ]] && grep -q "^metric_value:" "$run_log_dir/run.log" 2>/dev/null; then
            break
        fi
        local ts loss metric gpu_util gpu_mem
        ts=$(date -Iseconds)
        # >>> engine-specific: set loss/metric from this candidate's native
        # progress file here (e.g. ultralytics RUN_DIR/train/results.csv) <<<
        loss=""; metric=""
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

if [[ "${#CANDIDATES[@]}" -eq 0 ]]; then
    echo "CANDIDATES is empty — fill in the CONFIG section before running." >&2
    exit 1
fi

# --- Step 1: write EACH candidate its OWN new config file, copied from ----
# BASELINE_CONFIG (current_best) and never edited in place. This is what
# replaces git commit-per-candidate: provenance is the config_path itself.
echo "=== [$(date -Iseconds)] writing ${#CANDIDATES[@]} candidate configs (one new file each) ==="
declare -A CANDIDATE_CONFIG
for entry in "${CANDIDATES[@]}"; do
    NAME="${entry%%:*}"
    CONFIG_FILE="$SCEN_DIR/configs/${ENGINE}_${NAME}.cfg"
    cp "$BASELINE_CONFIG" "$CONFIG_FILE"

    # >>> engine-specific: apply $entry's fields as edits to CONFIG_FILE here <<<

    CANDIDATE_CONFIG["$NAME"]="$CONFIG_FILE"
    echo "  wrote $NAME -> $CONFIG_FILE"
done

# --- Step 2: launch all candidates concurrently, one per idle GPU ----------
# (fill in DEVICE_OF[$NAME] below to match each candidate's assigned GPU)
echo "=== [$(date -Iseconds)] launching ${#CANDIDATES[@]} runs in parallel ==="
PIDS=()
for entry in "${CANDIDATES[@]}"; do
    NAME="${entry%%:*}"
    CONFIG_FILE="$SCEN_DIR/configs/${ENGINE}_${NAME}.cfg"
    RUN_LOG_DIR="$RUNS_DIR/$NAME"
    mkdir -p "$RUN_LOG_DIR"
    bash "$RUN_SCRIPT" "$CONFIG_FILE" "$TIME_BUDGET_MIN" &
    PIDS+=("$!")
    echo "  [Trainer Agent] launched $NAME (pid $!)"
    # >>> engine-specific: pass the correct device for $NAME here <<<
    poll_candidate "$NAME" "0" "$RUN_LOG_DIR" &
    echo "  [Monitor Agent] polling $NAME -> $RUN_LOG_DIR/{monitor.log,metrics.csv}"
done

echo "=== [$(date -Iseconds)] waiting for all ${#PIDS[@]} runs to finish ==="
for pid in "${PIDS[@]}"; do
    wait "$pid"
done

# --- Step 3: evaluate + keep/discard EACH candidate independently ---------
echo "=== [$(date -Iseconds)] processing results, one candidate at a time ==="
CURRENT_BEST="$BASELINE_BEST"
CURRENT_BEST_CONFIG="$BASELINE_CONFIG"
for entry in "${CANDIDATES[@]}"; do
    NAME="${entry%%:*}"
    DESC="${entry##*:}"
    CANDIDATE_CFG="${CANDIDATE_CONFIG[$NAME]}"

    RUN_LOG="$RUNS_DIR/$NAME/run.log"

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
        if [[ "$METRIC_DIRECTION" == "maximize" ]]; then
            IS_BETTER=$(python3 -c "print(1 if float('$METRIC_VALUE') > float('$CURRENT_BEST') else 0)")
        else
            IS_BETTER=$(python3 -c "print(1 if float('$METRIC_VALUE') < float('$CURRENT_BEST') else 0)")
        fi
        if [[ "$IS_BETTER" == "1" ]]; then
            STATUS="keep"
        else
            STATUS="discard"
        fi
    fi

    echo "$NAME,$CANDIDATE_CFG,$METRIC_VALUE,$PEAK_VRAM_GB,$STATUS,$DOMAIN,$ENGINE,$DESC" >> "$RESULTS_CSV"
    echo "  $NAME -> status=$STATUS metric=$METRIC_VALUE (config $CANDIDATE_CFG)"

    if [[ "$STATUS" == "keep" ]]; then
        # No git branch to advance — just point current_best at this
        # candidate's own config file. Update scenario.yaml's current_best
        # (value, config_path, candidate) here.
        CURRENT_BEST="$METRIC_VALUE"
        CURRENT_BEST_CONFIG="$CANDIDATE_CFG"
    elif [[ "$STATUS" == "discard" ]]; then
        # Nothing to revert — this candidate's config file simply stays on
        # disk, unreferenced by current_best. Safe to leave it or clean it
        # up later; it never affects any other candidate.
        :
    fi
done

echo "=== [$(date -Iseconds)] batch complete. Results: ==="
cat "$RESULTS_CSV"
echo "=== current_best is now: $CURRENT_BEST ($CURRENT_BEST_CONFIG) ==="
echo "=== Next: check scenario.yaml's metric.target for PASS/FAIL, then either"
echo "=== continue the loop (step 1) or, if PASS or budget exhausted, hand off"
echo "=== to skills/knowledge-update/SKILL.md ==="
