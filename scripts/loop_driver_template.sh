#!/usr/bin/env bash
# Generic parallel experiment-loop driver template (Phase 3, parallel mode).
#
# Copy this into scenarios/<tag>/ and fill in the CONFIG section below.
# Implements the pattern from skills/experiment-loop/SKILL.md's "Parallel
# mode" section: N mutually-independent single-variable candidates from
# improve_guide.md, launched one per idle GPU via scripts/<engine>_run.sh,
# with EACH candidate committed and kept/discarded INDEPENDENTLY (never
# batched into one commit) so git history stays cleanly revertible.
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
# =============================================================================

mkdir -p "$LOG_DIR"
if [[ ! -f "$RESULTS_CSV" ]]; then
    echo "commit,metric_value,peak_vram_gb,status,domain,engine,description" > "$RESULTS_CSV"
fi

cd "$REPO_DIR"

if [[ "${#CANDIDATES[@]}" -eq 0 ]]; then
    echo "CANDIDATES is empty — fill in the CONFIG section before running." >&2
    exit 1
fi

# --- Step 1: commit EACH candidate's config as its OWN separate commit -----
# (Never combine into one batch commit — see experiment_logs/AGENT.md's hard
# rule. Per-candidate commits are what makes per-candidate discard a clean
# `git reset` instead of leaving abandoned config files in history.)
echo "=== [$(date -Iseconds)] writing + committing ${#CANDIDATES[@]} candidate configs (one commit each) ==="
declare -A CANDIDATE_COMMIT
for entry in "${CANDIDATES[@]}"; do
    NAME="${entry%%:*}"
    CONFIG_FILE="$SCEN_DIR/configs/${ENGINE}_${NAME}.cfg"

    # >>> engine-specific: write CONFIG_FILE from $entry's fields here <<<

    git add "$CONFIG_FILE"
    git commit -m "experiment(<tag>): candidate $NAME" -q
    CANDIDATE_COMMIT["$NAME"]=$(git rev-parse --short=7 HEAD)
    echo "  committed $NAME -> ${CANDIDATE_COMMIT[$NAME]}"
done

# --- Step 2: launch all candidates concurrently, one per idle GPU ----------
echo "=== [$(date -Iseconds)] launching ${#CANDIDATES[@]} runs in parallel ==="
PIDS=()
for entry in "${CANDIDATES[@]}"; do
    NAME="${entry%%:*}"
    CONFIG_FILE="$SCEN_DIR/configs/${ENGINE}_${NAME}.cfg"
    bash "$RUN_SCRIPT" "$CONFIG_FILE" "$TIME_BUDGET_MIN" &
    PIDS+=("$!")
    echo "  launched $NAME (pid $!)"
done

echo "=== [$(date -Iseconds)] waiting for all ${#PIDS[@]} runs to finish ==="
for pid in "${PIDS[@]}"; do
    wait "$pid"
done

# --- Step 3: evaluate + keep/discard EACH candidate independently ---------
echo "=== [$(date -Iseconds)] processing results, one candidate at a time ==="
CURRENT_BEST="$BASELINE_BEST"
for entry in "${CANDIDATES[@]}"; do
    NAME="${entry%%:*}"
    DESC="${entry##*:}"
    COMMIT="${CANDIDATE_COMMIT[$NAME]}"

    # >>> engine-specific: locate this candidate's run.log and RUN_DIR <<<
    RUN_LOG="/path/to/checkpoints/${NAME}/run.log"

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

    echo "$COMMIT,$METRIC_VALUE,$PEAK_VRAM_GB,$STATUS,$DOMAIN,$ENGINE,$NAME: $DESC" >> "$RESULTS_CSV"
    echo "  $NAME -> status=$STATUS metric=$METRIC_VALUE (commit $COMMIT)"

    if [[ "$STATUS" == "keep" ]]; then
        # Branch advances on this candidate's own commit; no other pending
        # commit is affected. Update scenario.yaml's current_best here.
        CURRENT_BEST="$METRIC_VALUE"
    elif [[ "$STATUS" == "discard" ]]; then
        # Revert ONLY this candidate's commit, independently of the others.
        # If this commit is not HEAD (other candidates' commits came after),
        # use `git rebase --onto` or cherry-pick-based removal instead of a
        # blind `git reset` to avoid discarding kept candidates too.
        git revert --no-edit "$COMMIT" -q || echo "  WARNING: manual revert needed for $COMMIT ($NAME)"
    fi
done

echo "=== [$(date -Iseconds)] batch complete. Results: ==="
cat "$RESULTS_CSV"
echo "=== Next: continue the loop (step 1) or, if budget exhausted, hand off to skills/knowledge-update/SKILL.md ==="
