---
name: monitor-agent
description: Periodically poll an in-progress training run for loss/metric/GPU health and record time-series snapshots plus basic anomaly alerts, without touching the run itself. Use this whenever the Trainer Agent has launched one or more candidates in Phase 3 and they are still running.
---

# Monitor Agent

Companion to `trainer/SKILL.md` and `skills/experiment-loop/SKILL.md`'s parallel mode. Runs **concurrently** with the Trainer Agent's `wait` on the training processes — it must never be the thing the loop blocks on.

## Output layout

```
experiment_logs/<tag>/runs/<candidate>/
    run.log        # Trainer Agent / engine wrapper output (six unified fields)
    monitor.log    # this skill's human-readable polling record + [ALERT] lines
    metrics.csv    # this skill's time-series snapshots
```

`metrics.csv` header:

```
timestamp,loss,metric_value,gpu_util,gpu_mem_mb
```

## Polling loop (default interval: 5 minutes)

For each in-progress candidate, once per interval:

1. **Read loss/metric** from the engine's native progress file (e.g. ultralytics `RUN_DIR/train/results.csv` last row) — see `trainer/references/<engine>.md` for the column names. If the file doesn't exist yet (run still initializing), record `loss=,metric_value=` (empty) and continue.
2. **Read GPU state** via `nvidia-smi --query-gpu=utilization.gpu,memory.used --format=csv,noheader,nounits -i <device>`.
3. **Append one row** to `metrics.csv`: `<ISO timestamp>,<loss>,<metric_value>,<gpu_util>,<gpu_mem_mb>`.
4. **Append one line** to `monitor.log`: `[<timestamp>] <candidate>: loss=<loss> metric=<metric_value> gpu_util=<gpu_util>% gpu_mem=<gpu_mem_mb>MB`.
5. **Anomaly check** (basic, no trend analysis):
   - If `loss` is `nan` or `inf` → append `[ALERT] loss=<value> at <timestamp>` to `monitor.log`.
   - Track a rolling count of consecutive polls with `gpu_util == 0`. If it reaches 3 (≈15 min at the default interval) → append `[ALERT] gpu_util=0 for 3 consecutive polls, possible hang` to `monitor.log`. Reset the counter once `gpu_util > 0` again.
6. Stop polling this candidate once its `run.log` contains the six unified fields (`metric_name:`/`metric_value:` etc.) or the process is confirmed no longer running.

## Implementation note (shell)

A minimal per-candidate poller (spawned once per candidate alongside the Trainer Agent's launch, backgrounded, `wait`-independent from the training PID):

```bash
poll_candidate() {
    local name="$1" results_csv="$2" device="$3" run_log_dir="$4"
    local metrics_csv="$run_log_dir/metrics.csv" monitor_log="$run_log_dir/monitor.log"
    echo "timestamp,loss,metric_value,gpu_util,gpu_mem_mb" > "$metrics_csv"
    local zero_streak=0
    while true; do
        [[ -f "$run_log_dir/run.log" ]] && grep -q "^metric_value:" "$run_log_dir/run.log" && break
        local ts loss metric gpu_util gpu_mem
        ts=$(date -Iseconds)
        if [[ -f "$results_csv" ]]; then
            # column layout is engine-specific; see trainer/references/<engine>.md
            loss=$(tail -1 "$results_csv" | awk -F, '{print $3}')
            metric=$(tail -1 "$results_csv" | awk -F, '{print $7}')
        else
            loss=""; metric=""
        fi
        read -r gpu_util gpu_mem <<< "$(nvidia-smi --query-gpu=utilization.gpu,memory.used --format=csv,noheader,nounits -i "$device" | tr ',' ' ')"
        echo "$ts,$loss,$metric,$gpu_util,$gpu_mem" >> "$metrics_csv"
        echo "[$ts] $name: loss=$loss metric=$metric gpu_util=${gpu_util}% gpu_mem=${gpu_mem}MB" >> "$monitor_log"
        if [[ "$loss" == "nan" || "$loss" == "inf" ]]; then
            echo "[ALERT] loss=$loss at $ts" >> "$monitor_log"
        fi
        if [[ "$gpu_util" == "0" ]]; then
            zero_streak=$((zero_streak + 1))
            if [[ "$zero_streak" -eq 3 ]]; then
                echo "[ALERT] gpu_util=0 for 3 consecutive polls, possible hang" >> "$monitor_log"
            fi
        else
            zero_streak=0
        fi
        sleep 300
    done
}
```

Each Trainer Agent launch loop should call `poll_candidate ... &` right after launching the training process, so it runs in the background for the lifetime of that candidate.

## Responsibilities

- Never write to `run.log` (Trainer/engine-owned) — always a separate `monitor.log`/`metrics.csv`.
- Never block the Trainer Agent's `wait` — the poller is its own background process per candidate, independent of the training PID.
- On `[ALERT]`, surface it to the Trainer Agent/human immediately in the driver's own console output, not just buried in `monitor.log`.

## Notes

- 5-minute interval is a default, not a hard requirement — adjust per scenario if a run's total budget is short enough that 5 minutes is too coarse (e.g. < 30 min budgets should poll more frequently).
- This skill intentionally does not do trend/regression analysis on the metric curve — that is a human/Knowledge-Update-Agent-time activity (Phase 4), not a Phase 3 real-time concern.
