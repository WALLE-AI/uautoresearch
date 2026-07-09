# OpenRLHF Adapter Notes

Distributed RLHF training engine built for large-scale PPO/DPO/GRPO/RLHF with Ray-based actor/critic/reward-model separation and vLLM-accelerated rollout generation. Prefer this over TRL when the scenario needs to scale RLHF across multiple nodes/many GPUs, or when rollout generation speed (via vLLM) is the bottleneck.

## Editable

- The RL algorithm config (reward shaping, KL coefficient, PPO/GRPO hyperparameters, learning rate, rollout batch size, number of Ray actors per role).
- The reward function wiring for scenario-specific verifiable rewards.
- Ray cluster resource allocation (GPUs per actor/critic/reward-model/rollout-engine role), when the scenario's hardware layout requires tuning it.

## Read-only

- The core Ray actor orchestration and distributed training loop.
- The vLLM rollout-generation internals.
- Any shared reward model/verifier implementation designated by `benchmark/SKILL.md` as ground truth.

## Launch convention

`scripts/openrlhf_run.sh <config> <time_budget_min>` should invoke OpenRLHF's Ray-based launch script with the given config. Because this spins up a multi-process Ray cluster, ensure the wrapper also handles clean Ray cluster teardown after the time budget elapses or the process exits — a leftover Ray cluster can silently break the next candidate's launch.

## Budget mapping

Distributed rollout+training throughput can vary significantly with cluster health (network, GPU placement) — always let the external time-budget wrapper be authoritative, and treat step-count-based comparisons across different cluster shapes as unreliable.

## Metric extraction

Use the held-out evaluation reward/pass-rate for `metric_value`, never the raw training-time reward, for the same reward-hacking reasons as veRL/ROLL/TRL.

## Common pitfalls

- Ray cluster startup failures (port conflicts, stale actors from a previous crashed run) look like training crashes but are actually infrastructure issues — check Ray logs before assuming a training bug.
- vLLM rollout engine version mismatches with the training-side model weights format can cause silent generation quality degradation without an outright crash.
- Same reward-hacking and KL-collapse risks as other RL engines — see `references/verl.md`.
