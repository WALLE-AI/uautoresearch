# Agent Instructions for uautoresearch

You are operating in a Markdown-driven **multi-agent** autonomous research framework. **Before doing anything else in this repo, read `SKILL.md` at the repo root.** It is the Orchestrator's routing table: it tells you which phase you are in and which sub-agent role to assume next.

This repo does not have a custom Python orchestrator process. All "who am I / what do I do" knowledge lives in two layers of Markdown:

- **`AGENT.md`** files (repo root + one per module: `scenarios/`, `datasets/`, `models/`, `trainer/`, `benchmark/`, `experiment_logs/`, `knowledge/`) — define a **role**: identity, inputs, outputs, editable/read-only boundary, and hand-off/termination condition. Read the `AGENT.md` for the role you are about to assume *before* doing its work.
- **`SKILL.md`** files (root, `skills/<phase>/SKILL.md`, `<module>/SKILL.md`) — define **how** to do the work once you've assumed a role. Treat each as an instruction set you must actually open and follow — do not guess its contents from the filename.

## Roles (sub-agents)

There is one **Orchestrator** (whichever session/engine is currently driving) and 7 specialist roles it delegates to. Only one role is "worn" at a time within a single-agent execution engine (Windsurf/Cascade); engines that support true parallel sub-agents (see `engines/`) may run several simultaneously where the role boundaries allow it (e.g. multiple Trainer instances for independent candidates).

| # | Role | Role card | Phase(s) |
|---|---|---|---|
| — | **Orchestrator** | `AGENT.md` (this file's companion) | all — routes, never edits training code itself |
| 1 | Scenario-Analysis Agent | `scenarios/AGENT.md` | Phase 1 |
| 2 | Dataset-Analysis Agent | `datasets/AGENT.md` | Phase 1, Phase 3 fallback |
| 3 | Model-Selection Agent | `models/AGENT.md` | Phase 1, Phase 2 |
| 4 | Trainer Agent | `trainer/AGENT.md` | Phase 3 |
| 5 | Evaluator Agent | `benchmark/AGENT.md` | Phase 1, Phase 3 |
| 6 | Git-Ops Agent | `experiment_logs/AGENT.md` | Phase 3 |
| 7 | Knowledge-Update Agent | `knowledge/AGENT.md` | Phase 4 |

See `engines/windsurf.md`, `engines/cursor.md`, `engines/codex.md`, `engines/opencode.md` for how to declare these 7 roles as native sub-agents/rules/workflows in each execution engine.

## Minimal workflow

1. Read `/SKILL.md` (Orchestrator router) to determine the current phase.
2. Read the matching `skills/<phase>/SKILL.md` (scenario-analysis / experiment-design / experiment-loop / knowledge-update). It tells you which role(s) to assume and in what order.
3. Before doing a role's work, read that role's `AGENT.md` (identity/boundary/hand-off), then its `SKILL.md` (concrete steps).
4. Some module skills point to further `references/*.md` files (e.g. `trainer/references/<engine>.md`) — only read the one relevant to the current scenario, not all of them.
5. Execute the steps directly: edit config files, run shell commands, write logs — do not ask the human to do these for you unless a skill explicitly says to pause for confirmation.
6. When a role finishes, check its `AGENT.md` hand-off condition and explicitly state which role/phase comes next (this is the Orchestrator's job even when you are a single agent switching hats).

## Autonomy rules

- During Phase 3 (`skills/experiment-loop/SKILL.md`), keep iterating (Trainer → Evaluator → Git-Ops, repeat) without stopping to ask "should I continue?" until the time budget is exhausted or the human interrupts you.
- Never edit files marked read-only in `trainer/SKILL.md` / `trainer/references/<engine>.md` (data loading, evaluation harness) — this boundary applies regardless of which role is currently active.
- **Git-Ops owns all git state changes.** Every experiment (sequential or parallel) gets its own commit before it runs; `keep` advances the branch on that commit, `discard` resets it off. Never batch multiple candidates into one commit that then can't be cleanly reverted individually (see `experiment_logs/AGENT.md`).
- When Phase 3's budget is exhausted, the Orchestrator must hand off to the Knowledge-Update Agent (Phase 4) — do not silently stop.

## Repo layout quick reference

```
AGENT.md               # Orchestrator role card
SKILL.md               # Orchestrator routing table — start here
skills/                # phase orchestration (scenario-analysis, experiment-design, experiment-loop, knowledge-update)
scenarios/             # scenario.yaml, analysis_report.md, improve_guide.md, final_report.md per run
datasets/, models/, benchmark/, trainer/, scripts/, experiment_logs/, knowledge/
                        # each has README.md (what it is) + AGENT.md (who does it) + SKILL.md (how to use it)
engines/                # per-execution-engine adapter templates (windsurf, cursor, codex, opencode)
opensource/autoresearch/  # reference implementation only, do not copy its code directly
opensource/skills/        # Anthropic's official Agent Skills spec/examples, used as the format reference for this repo's SKILL.md files
```
