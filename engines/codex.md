# Engine adapter: Codex (CLI/cloud agent)

Codex is driven by an `AGENTS.md` at the repo root (already present) plus, for multi-agent setups, per-task agent configuration (e.g. `~/.codex/config.toml` profiles, or per-invocation system prompts when scripting Codex programmatically). This adapter maps the 7 `uautoresearch` roles to distinct Codex invocation profiles rather than in-repo rule files, since Codex's primary steering mechanism is `AGENTS.md` + the prompt/profile it's launched with.

## Mapping

| uautoresearch concept | Codex construct |
|---|---|
| Orchestrator | The root `AGENTS.md` (already read automatically by Codex on every task) — no extra file needed. |
| Each of the 7 specialist roles | A named Codex **profile** (`~/.codex/config.toml`, `[profiles.<role>]`) whose `instructions`/system-prompt addendum tells it to read `<module>/AGENT.md` first, e.g. a `trainer-agent` profile. Alternatively, when scripting Codex via its CLI/SDK, pass the role's `AGENT.md` content as an explicit prefix instruction per invocation. |
| Phase 3 parallel mode | Launch N separate Codex CLI processes (one per candidate), each using the `trainer-agent` profile pinned to one candidate's config; collect results and run one `git-ops-agent`-profile invocation afterward for keep/discard, mirroring `scripts/loop_driver_template.sh`. |

## Setup

1. Keep `AGENTS.md` as-is at the repo root (Codex reads it automatically) — it already documents the role table.
2. Define one profile per role in `~/.codex/config.toml` (illustrative; exact schema depends on the Codex version in use):
   ```toml
   [profiles.trainer-agent]
   instructions_prefix = "Assume the Trainer Agent role. Read trainer/AGENT.md then trainer/SKILL.md before doing anything. Never touch read-only files (data loading, eval harness)."

   [profiles.evaluator-agent]
   instructions_prefix = "Assume the Evaluator Agent role. Read benchmark/AGENT.md then benchmark/SKILL.md before doing anything."
   ```
   Repeat for `scenario-analysis-agent`, `dataset-analysis-agent`, `model-selection-agent`, `git-ops-agent`, `knowledge-update-agent`.
3. Invoke with the matching profile for the current phase/role, e.g. `codex --profile trainer-agent "run the next candidate for scenarios/<tag>"`.
4. For parallel mode, script N concurrent `codex --profile trainer-agent ...` invocations (one per candidate/GPU) from a wrapper shell script analogous to `scripts/loop_driver_template.sh`, then a single `codex --profile git-ops-agent ...` invocation to reconcile keep/discard across all of them.

## Notes

- If the exact Codex config schema differs from the illustrative TOML above, keep the mapping principle (one profile = one role, each pointing at its `AGENT.md`) and adapt the syntax — this file is a template, not a guarantee of a specific Codex version's config format.
- Since Codex profiles are process-level, not conversation-level, this is the adapter best suited to true parallel sub-agent execution among the four engines listed here.
