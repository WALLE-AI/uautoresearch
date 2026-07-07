---
name: training-scripts
description: Generate and invoke the launch wrapper scripts that run a single training experiment within a fixed time budget for whichever trainer engine a scenario uses. Use this whenever the experiment loop needs to actually kick off a training run, or whenever a new trainer engine needs its wrapper script created.
---

# Training Scripts

This skill turns the universal launch convention defined in `trainer/SKILL.md` into a concrete, runnable script for each engine, and is the thing `skills/experiment-loop/SKILL.md` actually calls each iteration.

## Naming convention

```
scripts/<engine>_run.sh <config> <time_budget_min>
```

Where `<engine>` matches `trainer_engine` in `scenario.yaml` (`llama-factory`, `verl`, `roll`, `mmdetection`, `ultralytics`, `transformers`, or a `custom-<project>` engine per `trainer/SKILL.md`).

## What the wrapper script must do

1. Accept `<config>` (path to the engine-native config file/args) and `<time_budget_min>` as positional arguments.
2. Invoke the underlying engine's training entrypoint with `<config>`, per the engine's reference file in `trainer/references/`.
3. Enforce the time budget:
   - If the engine has a native time-based stop (e.g. ultralytics' `time=` argument), prefer it.
   - Otherwise, wrap the process so that it is asked to stop gracefully (allowing a checkpoint/log flush) once `time_budget_min` elapses — do not hard-kill (`SIGKILL`) as a first resort, since that can corrupt checkpoints or lose the final log lines needed for metric extraction.
4. Write all stdout/stderr to `experiment_logs/<tag>/runs/<candidate>/run.log` — **not** the engine's own `RUN_DIR`/checkpoint directory — per `experiment_logs/SKILL.md`'s centralized log-location convention. The wrapper should not assume it needs to redirect a second time if the caller already does; check the engine reference for the exact convention.
5. Exit with a non-zero code on crash so the caller can detect failure without having to grep for absence of output.

## Creating a new wrapper script

1. Read the target engine's `trainer/references/<engine>.md` for its native CLI/config conventions and budget-mapping guidance.
2. Write a short shell script (or thin Python wrapper if the engine is more naturally driven from Python) implementing the steps above.
3. Test it once manually with a short `time_budget_min` (e.g. 1-2 minutes) before handing it to the experiment loop, to confirm it actually launches, enforces the budget, and writes a parseable `run.log`.
4. Keep the script itself simple — logic that decides *what* to change belongs in `skills/experiment-loop/SKILL.md` and `improve_guide.md`, not in the launch script.

## Loop driver: sequential vs. parallel

`scripts/<engine>_run.sh` launches exactly **one** run. The Trainer/Git-Ops Agents drive the loop itself (per `skills/experiment-loop/SKILL.md`):

- **Sequential mode (default)**: the agent calls `scripts/<engine>_run.sh` once per iteration directly, interleaved with its own commit/reset/log steps. No extra driver script is needed.
- **Parallel mode (independent candidates, multi-GPU host)**: use `scripts/loop_driver_template.sh` as the starting point rather than hand-writing a new one-off driver per scenario. It implements the per-candidate-commit / per-candidate-keep-discard pattern from `skills/experiment-loop/SKILL.md`'s parallel mode — copy it into `scenarios/<tag>/` and fill in the `CANDIDATES` array, `BASE_MODEL`, `DATA_YAML`/config path, and `BASELINE_BEST`. Do not batch all candidates into a single commit (see `experiment_logs/AGENT.md`'s hard rule) — the template already commits each candidate separately.

## Notes

- Do not let the wrapper script silently swallow errors — if the underlying engine command fails to even start (e.g. bad config path), that should be obvious in `run.log`, not hidden behind a generic "crash" with no trace.
- Keep wrapper scripts engine-specific and thin; do not build a single mega-script that branches on engine name internally — one script per engine is easier to keep correct as engines evolve.
- The parallel loop driver is generic across engines (it only shells out to `scripts/<engine>_run.sh`) — do not fork per-engine copies of it; parameterize instead.
