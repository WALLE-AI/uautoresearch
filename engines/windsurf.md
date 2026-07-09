# Engine adapter: Windsurf (Cascade)

How to declare the 8 `uautoresearch` sub-agent roles (see `AGENTS.md`) as native Windsurf constructs. Windsurf's Cascade agent does not (as of writing) support spawning fully independent parallel sub-agent sessions from within a single conversation — this adapter therefore uses the **single-agent, role-switching** pattern: one Cascade session reads `AGENTS.md` + the relevant `AGENT.md`/`SKILL.md` pair and explicitly states which role it is "wearing" at each step, exactly as described in the root `AGENTS.md`. There is no Git-Ops role — the Evaluator Agent owns keep/discard and the results ledger, and candidates are independent config files rather than git commits.

## Mapping

| uautoresearch concept | Windsurf construct |
|---|---|
| Orchestrator | The active Cascade conversation itself; global behavior pinned via a workspace rule (`.windsurf/rules/uautoresearch.md`, always-on) that points to `AGENTS.md`. |
| 8 specialist roles | Not separate Cascade sessions — represented as `.windsurf/workflows/<role>.md` slash-commands the user (or Cascade itself, if instructed) can invoke to jump straight into a role's `AGENT.md`+`SKILL.md` without re-deriving routing state. |
| Phase 3 parallel mode | `run_command` (non-blocking, background) calls to `scripts/<engine>_run.sh` per candidate, coordinated by the single Cascade session per `skills/experiment-loop/SKILL.md`'s parallel mode — Cascade itself acts as the concurrent-launch coordinator since Windsurf lacks native multi-agent fan-out. |

## Setup

1. Create `.windsurf/rules/uautoresearch.md` (always-on activation) with:
   ```markdown
   ---
   trigger: always_on
   ---
   Before any research/training task in this repo, read AGENTS.md and SKILL.md
   at the repo root. Follow their routing rules and role definitions exactly.
   ```
2. Optionally create one `.windsurf/workflows/<role>.md` per role for fast manual invocation, e.g. `.windsurf/workflows/trainer-agent.md`:
   ```markdown
   ---
   description: Assume the Trainer Agent role for the current scenario
   ---
   1. Read trainer/AGENT.md (identity/boundary/hand-off).
   2. Read trainer/SKILL.md and the trainer/references/<engine>.md matching
      the current scenario's trainer_engine.
   3. Proceed per skills/experiment-loop/SKILL.md's Trainer Agent steps.
   ```
   Repeat for `scenario-analysis-agent`, `dataset-analysis-agent`, `model-selection-agent`, `training-plan-agent`, `monitor-agent`, `evaluator-agent`, `knowledge-update-agent`.
3. For Phase 3 parallel mode, use the `run_command` tool with `Blocking: false` for each candidate launch (mirrors `scripts/loop_driver_template.sh`'s `&`/`wait` pattern), and `command_status`/`read_terminal` to poll completion — do not block the whole conversation on one run when others could proceed.

## Notes

- Since there is only one active session, role-switching is disciplined by convention (always state "Assuming role: X" before acting), not enforced by the platform. Treat `AGENT.md` boundary violations as bugs to self-correct, not something Windsurf blocks for you.
- If Windsurf later adds native sub-agent/multi-session support, promote each `.windsurf/workflows/<role>.md` to a true sub-agent definition without changing the underlying `AGENT.md`/`SKILL.md` content.
