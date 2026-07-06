# ROLL Adapter Notes

Alternative RL training engine for LLMs/VLMs, used as a secondary option to veRL — pick based on which is already available/installed, or when a scenario's specific RL algorithm/scaling needs are better supported by ROLL.

## Editable

- RL algorithm and training config (same categories as veRL: reward shaping, rollout batch size, learning rate, KL/entropy coefficients, number of steps).

## Read-only

- Core rollout/training orchestration internals.
- The reward/verifier implementation designated by `benchmark/SKILL.md` as the ground-truth signal.

## Launch convention

`scripts/roll_run.sh <config> <time_budget_min>` — same pattern as veRL: invoke the native training entrypoint, bound wall-clock time with an external wrapper that allows a graceful checkpoint before terminating.

## Budget mapping

Same caveat as veRL: RL throughput is variable, so treat the external time-budget wrapper as authoritative rather than a fixed step count.

## Metric extraction

Same as veRL: always use the held-out evaluation reward/pass-rate for `metric_value`, never the raw training-time reward.

## Choosing ROLL vs. veRL

- If both are available and the scenario has no strong preference, default to whichever the human has already used successfully for a similar scenario (check `knowledge/SKILL.md`).
- If the scenario needs a specific scaling/parallelism strategy only one of the two supports well, that constraint decides it — confirm during Phase 1 model/engine selection, not mid-loop.

## Common pitfalls

Same reward-hacking and KL-collapse risks as veRL — see `references/verl.md` for details, since the underlying RL dynamics concerns are engine-agnostic.
