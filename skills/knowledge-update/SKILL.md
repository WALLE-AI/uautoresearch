---
name: knowledge-update
description: Phase 4 orchestration skill for uautoresearch. Use after an experiment loop run has finished (budget exhausted or interrupted) to fold what was learned back into the persistent knowledge base, and use before starting a new scenario analysis to check whether relevant experience already exists. This is what makes the framework improve across runs instead of repeating the same failed experiments.
---

# Phase 4: Knowledge Accumulation

Every finished scenario run should leave the `knowledge/` base a little smarter. This skill defines both directions: writing new experience in, and reading existing experience out.

## Write-back (after a scenario run finishes)

1. **Gather inputs**: `scenarios/<tag>/scenario.yaml`, `analysis_report.md`, `improve_guide.md`, and `experiment_logs/<tag>/experiment_results.csv`.
2. **Extract the signal, not the noise.** Summarize:
   - Which candidate techniques were `keep` vs `discard` vs `crash`, and by how much they moved the metric.
   - Any hyperparameter ranges that worked well or clearly did not, for this domain/task_type/model size.
   - Data strategies that helped or hurt.
   - Failure modes worth remembering (e.g. "LoRA rank > 64 OOMs on this GPU with this batch size", "this augmentation policy hurt mAP on small objects").
3. **Delegate the actual write to `knowledge/SKILL.md`**, which knows the file layout and structured Knowledge Card format for the experience base. Do not write directly into `knowledge/` files without following its conventions.
4. **Produce `scenarios/<tag>/final_report.md`** summarizing the whole run for the human:

```markdown
# Final Report: <tag>

## Scenario
## Baseline vs Best Result
## Timeline of Kept Changes
## Key Learnings (also written to knowledge/)
## Recommended Next Steps
```

## Read (before starting a new scenario analysis)

When `skills/scenario-analysis/SKILL.md` runs its 7-dimension diagnosis (specifically the "baseline history" dimension), it should call into `knowledge/SKILL.md` to check whether a similar domain/task_type/model combination has been tried before, and reuse those learnings rather than starting from zero. This is a one-line delegation, not something this skill needs to re-implement.

## Notes

- Do not fabricate learnings — only record what the logged experiments actually show.
- Keep entries scoped and attributable (which scenario/tag they came from) so future contradictory evidence can update rather than duplicate them.
- This skill **always runs** at the end of Phase 3, regardless of whether `scenario.yaml`'s target metric was reached. If it was not reached, the Orchestrator routes back to the Training-Plan Agent (`planning/AGENT.md`) for re-planning immediately after this skill finishes — do not mark the scenario `status: done` in that case.
