# Dataset Construction Frameworks

Reference notes for `datasets/SKILL.md`. Read the section relevant to the chosen framework before use; installation/version pinning is left to the concrete integration (tracked as an open item in the project plan).

## distilabel

General-purpose framework for building synthetic data generation pipelines with LLMs: define a pipeline of steps (generation, filtering, scoring, deduplication) and run it over a set of seed inputs. Good default choice when you need custom multi-stage generation with quality filtering and don't need a specific technique below.

- Use for: instruction data generation with custom quality gates, preference data (chosen/rejected pairs) for RLHF, general LLM-in-the-loop data pipelines.
- Typical shape: seed inputs → generation step(s) → scoring/filtering step(s) → deduplication → final dataset.

## dataagent

Agent-driven data curation and generation workflows — an agent plans and executes multi-step data collection/curation tasks rather than following a fixed pipeline.

- Use for: cases where the data need is loosely specified and benefits from an agent iteratively deciding what to collect/generate/filter next, rather than a fixed pipeline.

## Magpie

Extracts high-quality instruction data directly from an already-aligned LLM by exploiting its auto-regressive nature: feed only the pre-query template (no seed instruction) and let the aligned model generate the instruction itself, then generate the response. No seed prompts or human-written instructions required.

- Use for: bootstrapping a large, diverse instruction-following dataset from scratch when you have access to a strong aligned model but no seed instruction set.
- Caveat: quality depends heavily on the strength/alignment of the model being sampled from; always filter/dedupe the output.

## Evo-Instruct

Evolutionary augmentation of existing instructions (the technique behind WizardLM-style datasets): apply evolution operators (add constraints, deepen, concretize, increase reasoning steps, broaden) to existing instructions to produce more complex and diverse variants, then generate responses for the evolved instructions.

- Use for: when you already have a base instruction set but it's too easy/homogeneous, and you need to raise difficulty/diversity without collecting entirely new seed data.

## Choosing between them

| Need | Framework |
|---|---|
| Custom multi-stage generation + filtering pipeline | distilabel |
| Loosely-specified, agent-driven curation | dataagent |
| Bootstrap diverse instructions from zero seeds | Magpie |
| Increase complexity/diversity of existing instructions | Evo-Instruct |

These are not mutually exclusive — a common pattern is Magpie (or existing data) for breadth, Evo-Instruct for depth/difficulty, and distilabel to wrap the whole thing in a filtering/scoring pipeline.
