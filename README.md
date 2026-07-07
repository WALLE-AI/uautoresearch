# uautoresearch
* uautoresearch 是能够自动化完成LLM/VLM CV NLP等算法训练的多智能体框架
* 支持LLM/VLM SFT/RLHF/FT等训练
* 支持CV 目标检测/分割/分类等训练
* 支持NLP 文本分类/生成/理解等训练
* 由 1 个 Orchestrator + 7 个专职子智能体(Scenario-Analysis / Dataset-Analysis / Model-Selection / Trainer / Evaluator / Git-Ops / Knowledge-Update)组成，角色定义见各模块目录下的 `AGENT.md`，路由规则见根目录 `AGENTS.md`/`SKILL.md`
* 支持 codex / opencode / cursor / windsurf 四种执行引擎适配，见 `engines/`
