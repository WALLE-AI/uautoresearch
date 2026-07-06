---
name: knowledge-base
description: Retrieve prior experience relevant to a new scenario, and write back new experience after a scenario run finishes. Use this whenever Phase 1's baseline-history diagnosis needs to check for similar past scenarios, whenever Phase 2 needs to avoid re-proposing already-discarded techniques, or whenever Phase 4 needs to persist learnings from a finished run.
---

# Knowledge Base

`knowledge/` is the framework's long-term memory across scenarios and runs. It contains two kinds of content: curated background material (e.g. `survey/`, which holds domain surveys like `survey/segement/` for segmentation) and accumulated experiment experience (hyperparameter/technique learnings, cost-saving strategies, hardware notes). This skill governs how both are read and how new experience gets added.

## Directory layout

```
knowledge/
├── survey/                    # curated background reading, organized by topic
│   └── <topic>/Part..._Chapter..._<name>.md
└── experience/                 # accumulated experiment experience, organized by domain
    ├── llm.md
    ├── vlm.md
    ├── cv.md
    ├── nlp.md
    ├── data-strategy.md         # cross-domain data construction/quality learnings
    ├── cost-and-hardware.md     # GPU/cost-saving strategies
    └── evaluation.md            # benchmark/eval pitfalls learned across scenarios
```

If `knowledge/experience/` does not exist yet, create it with these files (starting empty except for a one-line header) the first time a write-back happens — don't wait for someone to pre-create it.

## Retrieval (used by Phase 1 and Phase 2)

1. Identify the current scenario's `domain` and `task_type`.
2. Read the matching `knowledge/experience/<domain>.md` file (and `data-strategy.md`, `cost-and-hardware.md`, `evaluation.md` if relevant) looking for entries tagged with a similar `task_type` or `base_model`.
3. Surface directly relevant entries to whichever phase is asking:
   - Phase 1's 7-dimension diagnosis "baseline history" section should cite what was found (or note that nothing relevant exists yet).
   - Phase 2 should not re-propose a technique already recorded as a clear `discard` for a closely matching scenario without a stated reason why this time might be different.
4. If `knowledge/survey/` has a topic directly relevant to the scenario's domain (e.g. a segmentation scenario and `survey/segement/`), point the relevant phase to it for deeper background rather than re-deriving well-known domain knowledge from scratch.

## Write-back (used by Phase 4, via `skills/knowledge-update/SKILL.md`)

1. Take the summarized signal handed off by `skills/knowledge-update/SKILL.md` (kept/discarded techniques, working/non-working hyperparameter ranges, data strategies, failure modes).
2. Append entries to the appropriate `knowledge/experience/<file>.md`, using this format so entries stay scannable:

```markdown
## <task_type> on <base_model> (<domain>) — from scenario `<tag>`, <date>
- **Worked**: <technique/hyperparameter range> — <effect on metric>
- **Did not work**: <technique> — <effect / why>
- **Failure mode**: <e.g. OOM at LoRA rank > 64 with batch size 8 on 24GB GPU>
- **Data note**: <if applicable>
```

3. Never delete or overwrite existing entries — if new evidence contradicts an old entry, append a new entry that references it (e.g. "contradicts entry from `<old-tag>`: ...") rather than silently erasing history.
4. Keep entries attributable to a scenario tag and date so provenance is always traceable.

## Notes

- This skill only manages the knowledge files themselves — it does not decide what counts as a "learning" (that's `skills/knowledge-update/SKILL.md`'s job) or run any experiments.
- Prefer many small, specific entries over few large vague ones — "LoRA rank 32 outperformed rank 8 by 0.02 val_bpb on a 500M model, 24GB GPU" is useful; "LoRA works well" is not.
