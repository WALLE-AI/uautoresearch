# veRL Adapter Notes

RL-focused training engine for LLMs/VLMs, built around efficient distributed rollout + training for RLHF/RLVR-style algorithms (PPO, GRPO, and similar).

## Editable

- The RL algorithm config (reward shaping, KL coefficient, rollout batch size, PPO/GRPO hyperparameters, learning rate, number of rollout/train steps).
- The reward function wiring, when the scenario's reward is a scenario-specific verifiable function (e.g. a math/code checker) rather than a learned reward model.

## Read-only

- The core rollout/training loop and distributed orchestration code.
- Any shared reward model or verifier implementation that `benchmark/SKILL.md` designated as the ground-truth evaluation signal — modifying it would invalidate keep/discard comparisons.

## Launch convention

`scripts/verl_run.sh <config> <time_budget_min>` should invoke veRL's training entrypoint with the given config. Because RL training is rollout-heavy and variable-latency, prefer bounding by wall-clock time via an external wrapper over relying solely on step counts, and ensure the wrapper allows the current rollout/update cycle to finish and checkpoint before killing the process.

## Budget mapping

RL training throughput can vary a lot run-to-run depending on rollout length/acceptance — do not assume a fixed step count maps to a fixed wall-clock time the way it might for supervised training. Always let the external time-budget wrapper be authoritative.

## Metric extraction

Map the reward/verifiable-task pass-rate reported at evaluation checkpoints to `metric_value`. If veRL reports both training reward and a held-out eval reward, always use the held-out eval number for keep/discard decisions, never the training-time reward (which can be inflated by reward hacking).

## Common pitfalls

- Reward hacking: a rising training reward with a flat or falling held-out eval metric is a discard, not a keep, even though the raw training curve looks good.
- KL coefficient too low can cause policy collapse late in a run that looks fine early — if a scenario runs multiple sequential experiments building on the same policy, watch for this across iterations, not just within one run.
