# TRL Adapter Notes

Hugging Face's RLHF library (PPO/DPO/GRPO/reward-model training), tightly integrated with `transformers`/`accelerate`/`peft`. Prefer this over veRL/ROLL when the scenario is already HF-ecosystem-native (HF model, HF dataset, small-to-mid scale) and doesn't need veRL/ROLL's heavier distributed-rollout infrastructure.

## Editable

- The RL algorithm config (PPO/DPO/GRPO hyperparameters: KL coefficient, learning rate, batch size, number of PPO epochs per batch, reference-model sync frequency).
- LoRA/PEFT adapter configuration, when using parameter-efficient fine-tuning.
- The reward function wiring for scenario-specific verifiable rewards (same pattern as veRL/ROLL).

## Read-only

- The core `PPOTrainer`/`DPOTrainer`/`GRPOTrainer` training loop internals.
- Any shared reward model or verifier implementation designated by `benchmark/SKILL.md` as the ground-truth evaluation signal.

## Launch convention

`scripts/trl_run.sh <config> <time_budget_min>` should invoke the TRL trainer script (typically via `accelerate launch`) with the given config. Since TRL runs are usually smaller-scale than veRL/ROLL, native `max_steps`/time-based stopping is often sufficient; still wrap with an external time-budget check as a fallback.

## Budget mapping

TRL throughput is more predictable than veRL/ROLL for a fixed model/hardware combination since rollout length is often more bounded (e.g. DPO has no rollout at all), but still let the external time-budget wrapper be authoritative rather than assuming steps-to-wallclock is fixed across candidates.

## Metric extraction

For DPO/reward-model training, map the held-out eval loss/accuracy to `metric_value`. For PPO/GRPO, always use the held-out eval reward/pass-rate, never the training-time reward, for the same reward-hacking reasons as veRL/ROLL.

## Common pitfalls

- Reference-model KL divergence exploding when the reference model isn't properly frozen/synced — check this before blaming the learning rate.
- PEFT/LoRA + PPO interactions: forgetting to merge or properly reload the adapter before evaluation can silently evaluate the wrong model.
- Same reward-hacking and KL-collapse risks as veRL/ROLL — see `references/verl.md` for the underlying RL dynamics concerns, which are engine-agnostic.
