# Engine adapter: opencode

opencode supports project-level agent configuration (`.opencode/agent/*.md` or `opencode.json`, depending on version) with named custom agents/modes that can be switched between or invoked as sub-agents. This adapter maps the 7 `uautoresearch` roles 1:1 to opencode custom agent definitions.

## Mapping

| uautoresearch concept | opencode construct |
|---|---|
| Orchestrator | The default/primary opencode agent, configured to always read `AGENTS.md`/`SKILL.md` first (via a project-level system-prompt addition or `AGENTS.md` auto-discovery if the opencode version supports it natively). |
| Each of the 7 specialist roles | One custom agent file under `.opencode/agent/<role>.md`, with frontmatter restricting its tools/scope and a body that points to the role's `AGENT.md` + `SKILL.md`. |
| Phase 3 parallel mode | opencode's sub-agent invocation (calling a named agent as a tool from the orchestrator agent) launched N times concurrently, one per candidate — each sub-agent call scoped to the `trainer-agent` role for one candidate; the orchestrator then invokes the `git-ops-agent` once to reconcile results, mirroring `scripts/loop_driver_template.sh`. |

## Setup

1. `.opencode/agent/trainer-agent.md`:
   ```markdown
   ---
   description: Trainer Agent — builds and launches one training run within budget
   mode: subagent
   tools:
     write: true
     edit: true
     bash: true
   ---
   You are the Trainer Agent for uautoresearch. Read trainer/AGENT.md, then
   trainer/SKILL.md and the matching trainer/references/<engine>.md, before
   making any change. Never edit read-only files (data loading, evaluation
   harness). Launch only via scripts/<engine>_run.sh.
   ```
2. Repeat for `scenario-analysis-agent.md`, `dataset-analysis-agent.md`, `model-selection-agent.md`, `evaluator-agent.md`, `git-ops-agent.md`, `knowledge-update-agent.md`, each pointing at its own `<module>/AGENT.md`.
3. Configure the primary/orchestrator agent (`.opencode/agent/build.md` or equivalent default) to read root `AGENTS.md`/`SKILL.md` and delegate to the named sub-agents above via opencode's agent-calling mechanism, rather than doing role-specific work itself.
4. For Phase 3 parallel mode, have the orchestrator agent invoke `trainer-agent` N times concurrently (one per independent candidate), wait for all to complete, then invoke `git-ops-agent` once to process keep/discard/logging per candidate — never let a sub-agent invocation batch multiple candidates' git commits together.

## Notes

- Restrict each role's `tools:` in its agent frontmatter to what `AGENT.md`'s boundary section allows (e.g. `git-ops-agent` needs `bash: true` for git commands but arguably should not need broad `write`/`edit` outside `experiment_logs/` and `scenario.yaml`).
- If the installed opencode version's agent-definition schema differs from the illustrative frontmatter above, keep the mapping principle (one `.opencode/agent/*.md` = one `AGENT.md` role) and adapt the syntax accordingly.
