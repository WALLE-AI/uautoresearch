#!/usr/bin/env bash
# Launch wrapper for the custom-bfdd-segmentation trainer engine.
# See trainer/references/custom-bfdd-segmentation.md for the full adapter contract.
#
# Usage:
#   scripts/custom-bfdd-segmentation_run.sh <config> <time_budget_min>
#
# <config> is a shell-sourceable file defining:
#   XIBEIYUAN_ROOT   absolute path to the xibeiyuan project (contains train_bfdd_swin.py, .venv/)
#   ENCODER_NAME     swin_small | swin_base | swin_large
#   BATCH_SIZE       per-GPU batch size
#   ACCUMULATE       gradient accumulation steps
#   EPOCHS           upper bound on epochs (the time budget is the real cutoff, see below)
#   LR               learning rate
#   EARLY_STOP       early-stop patience (epochs without improvement)
#   CHECKPOINT_DIR   absolute path, must be unique per experiment iteration
#   PRETRAIN_CKPT    absolute path to the checkpoint to fine-tune from
#   NUM_GPUS         (optional, default 8)
#
# Writes run.log in the current working directory with the six unified fields
# required by experiment_logs/SKILL.md.

set -uo pipefail

CONFIG="${1:?usage: $0 <config> <time_budget_min>}"
TIME_BUDGET_MIN="${2:?usage: $0 <config> <time_budget_min>}"

# shellcheck disable=SC1090
source "$CONFIG"

: "${XIBEIYUAN_ROOT:?config must set XIBEIYUAN_ROOT}"
: "${ENCODER_NAME:?config must set ENCODER_NAME}"
: "${BATCH_SIZE:?config must set BATCH_SIZE}"
: "${ACCUMULATE:?config must set ACCUMULATE}"
: "${EPOCHS:?config must set EPOCHS}"
: "${LR:?config must set LR}"
: "${EARLY_STOP:?config must set EARLY_STOP}"
: "${CHECKPOINT_DIR:?config must set CHECKPOINT_DIR}"
: "${PRETRAIN_CKPT:?config must set PRETRAIN_CKPT}"
NUM_GPUS="${NUM_GPUS:-8}"

RUN_LOG="$(pwd)/run.log"
: > "$RUN_LOG"

TIMEOUT_SECONDS=$(( TIME_BUDGET_MIN * 60 ))
TORCHRUN="${XIBEIYUAN_ROOT}/.venv/bin/torchrun"

if [[ ! -x "$TORCHRUN" ]]; then
    echo "ERROR: torchrun not found/executable at $TORCHRUN" | tee -a "$RUN_LOG"
    exit 1
fi
if [[ ! -f "$PRETRAIN_CKPT" ]]; then
    echo "ERROR: PRETRAIN_CKPT not found: $PRETRAIN_CKPT" | tee -a "$RUN_LOG"
    exit 1
fi

mkdir -p "$CHECKPOINT_DIR"

# Background VRAM poller (peak across all NUM_GPUS, in MB).
VRAM_PEAK_FILE="$(mktemp)"
echo 0 > "$VRAM_PEAK_FILE"
(
    while true; do
        cur=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null | sort -n | tail -1)
        prev=$(cat "$VRAM_PEAK_FILE" 2>/dev/null || echo 0)
        if [[ -n "$cur" ]] && (( cur > prev )); then
            echo "$cur" > "$VRAM_PEAK_FILE"
        fi
        sleep 5
    done
) &
POLLER_PID=$!

START_TS=$(date +%s)

(
    cd "$XIBEIYUAN_ROOT" || exit 1
    HF_HUB_OFFLINE=1 PYTHONPATH=. timeout --signal=TERM "$TIMEOUT_SECONDS" \
        "$TORCHRUN" --standalone --nproc_per_node="$NUM_GPUS" \
        train_bfdd_swin.py \
        --encoder_name "$ENCODER_NAME" \
        --batch_size "$BATCH_SIZE" \
        --accumulate "$ACCUMULATE" \
        --epochs "$EPOCHS" \
        --lr "$LR" \
        --early_stop "$EARLY_STOP" \
        --checkpoint_dir "$CHECKPOINT_DIR" \
        --pretrain_ckpt "$PRETRAIN_CKPT" \
        --finetune
) >> "$RUN_LOG" 2>&1
TRAIN_EXIT=$?

END_TS=$(date +%s)
TOTAL_SECONDS=$(( END_TS - START_TS ))

kill "$POLLER_PID" 2>/dev/null || true
wait "$POLLER_PID" 2>/dev/null || true
PEAK_VRAM_MB=$(cat "$VRAM_PEAK_FILE" 2>/dev/null || echo 0)
rm -f "$VRAM_PEAK_FILE"

# timeout exit code 124 = graceful budget expiry, not a crash.
if [[ $TRAIN_EXIT -ne 0 && $TRAIN_EXIT -ne 124 ]]; then
    echo "CRASH: train_bfdd_swin.py exited with code $TRAIN_EXIT" | tee -a "$RUN_LOG"
    exit "$TRAIN_EXIT"
fi

METRIC_VALUE=$(grep -oE 'mIoU: [0-9.]+' "$RUN_LOG" | tail -1 | awk '{print $2}')
TRAINING_SECONDS=$(grep -oE 'Time: [0-9.]+s' "$RUN_LOG" | awk '{sum += substr($2, 1, length($2)-1)} END {print sum+0}')

if [[ -z "$METRIC_VALUE" ]]; then
    echo "CRASH: no epoch completed within the time budget (no mIoU found in run.log)" | tee -a "$RUN_LOG"
    exit 1
fi

BEST_CKPT="${CHECKPOINT_DIR}/best.pth"
NUM_PARAMS_M="0"
if [[ -f "$BEST_CKPT" ]]; then
    NUM_PARAMS_M=$("${XIBEIYUAN_ROOT}/.venv/bin/python" -c "
import torch
ckpt = torch.load('${BEST_CKPT}', map_location='cpu', weights_only=False)
sd = ckpt['state_dict']
n = sum(v.numel() for v in sd.values())
print(f'{n/1e6:.2f}')
" 2>/dev/null || echo "0")
fi

{
    echo "metric_name:      val_mIoU"
    echo "metric_value:     ${METRIC_VALUE}"
    echo "training_seconds: ${TRAINING_SECONDS}"
    echo "total_seconds:    ${TOTAL_SECONDS}"
    echo "peak_vram_mb:     ${PEAK_VRAM_MB}"
    echo "num_params_M:     ${NUM_PARAMS_M}"
} >> "$RUN_LOG"

exit 0
