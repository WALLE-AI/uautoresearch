# Agent Instructions for uautoresearch

You are operating in a Markdown-driven autonomous research framework. **Before doing anything else in this repo, read `SKILL.md` at the repo root.** It is the router that tells you which phase skill to read next based on what state the current scenario is in.

This repo does not have a custom Python orchestrator. All "how to do X" knowledge lives in `SKILL.md` files (root, `skills/<phase>/SKILL.md`, and `<module>/SKILL.md`). Treat each `SKILL.md` as an instruction set you must actually open and follow — do not guess its contents from the filename, and do not skip straight to editing files without reading the relevant skill first.

## Minimal workflow

1. Read `/SKILL.md` (root router).
2. Follow its routing rules to the correct `skills/<phase>/SKILL.md` (scenario-analysis / experiment-design / experiment-loop / knowledge-update).
3. That phase skill will tell you which module `SKILL.md` files to read (`scenarios/`, `datasets/`, `models/`, `benchmark/`, `trainer/`, `scripts/`, `experiment_logs/`, `knowledge/`). Read each one before using it.
4. Some module skills point to further `references/*.md` files (e.g. `trainer/references/<engine>.md`) — only read the one relevant to the current scenario, not all of them.
5. Execute the steps directly: edit config files, run shell commands, write logs — do not ask the human to do these for you unless a skill explicitly says to pause for confirmation.

## Autonomy rules

- During Phase 3 (`skills/experiment-loop/SKILL.md`), keep iterating without stopping to ask "should I continue?" until the time budget is exhausted or the human interrupts you.
- Never edit files marked read-only in `trainer/SKILL.md` / `trainer/references/<engine>.md` (data loading, evaluation harness).
- Always commit before each experiment run and `git reset` on discard — never leave the repo in a dirty, half-finished state between iterations.

## Repo layout quick reference

```
SKILL.md              # start here
skills/                # phase orchestration (scenario-analysis, experiment-design, experiment-loop, knowledge-update)
scenarios/             # scenario.yaml, analysis_report.md, improve_guide.md, final_report.md per run
datasets/, models/, benchmark/, trainer/, scripts/, experiment_logs/, knowledge/
                        # each has README.md (what it is) + SKILL.md (how to use it)
opensource/autoresearch/  # reference implementation only, do not copy its code directly
opensource/skills/        # Anthropic's official Agent Skills spec/examples, used as the format reference for this repo's SKILL.md files
```
