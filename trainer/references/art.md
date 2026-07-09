# ART Adapter Notes

Agent Reinforcement Trainer — an RL training engine purpose-built for training LLM-based agents on multi-step, tool-using tasks (as opposed to single-turn RLHF), using GRPO-style training over full agent trajectories/rollouts. Prefer this over veRL/ROLL/TRL/OpenRLHF when the scenario's task is inherently agentic (multi-turn tool calls, environment interaction) rather than single-turn generation.

## Editable

- The RL algorithm config (GRPO hyperparameters, rollout group size, learning rate, number of trajectories per training step).
- The task/environment definition and reward function — for agentic tasks the "reward" is usually a task-completion/verifier signal over the whole trajectory, which is scenario-specific and expected to be authored per scenario.
- The agent's tool/action-space wiring, when it's part of what's being optimized (e.g. which tools are available, prompt template for tool use).

## Read-only

- The core trajectory-collection/training loop internals.
- Any shared verifier/grader implementation designated by `benchmark/SKILL.md` as the ground-truth evaluation signal for task completion — do not let the agent modify its own grader.

## Launch convention

`scripts/art_run.sh <config> <time_budget_min>` should invoke ART's training entrypoint against the scenario's environment/task definition. Multi-step agent rollouts can be slow and variable-length (an agent might loop or get stuck) — the external time-budget wrapper must allow an in-progress trajectory to either finish or be cleanly truncated without corrupting the training batch.

## Budget mapping

Agent trajectory throughput is the most variable of any engine here (trajectory length depends on the agent's own behavior, including failure loops) — always treat the external time-budget wrapper as authoritative, and expect much higher run-to-run variance in wall-clock-per-step than single-turn RL engines.

## Metric extraction

Map the held-out task-completion rate / verifier pass-rate (evaluated on held-out tasks, not the training task distribution) to `metric_value`. Never use in-training rollout success rate directly, since it can be inflated by the agent exploiting the training task distribution or environment quirks rather than genuinely improving.

## Common pitfalls

- Agents getting stuck in tool-call loops (e.g. repeatedly calling a failing tool) inflate wall-clock time per trajectory without producing useful training signal — watch for this via the Monitor Agent's GPU-utilization/hang detection, since a stuck agent loop can look like a healthy but slow run.
- Reward/verifier design for multi-step tasks is much easier to get subtly wrong than single-turn RLHF (e.g. partial-credit shaping that inadvertently rewards excessive tool calls) — treat verifier changes as a Phase 2 design discussion, not a casual Phase 3 tweak.
- Same general reward-hacking caution as other RL engines — see `references/verl.md`.
