# uautoresearch
* uautoresearch 是能够自动化完成LLM/VLM CV NLP等算法训练的多智能体框架
* 支持LLM/VLM SFT/RLHF/FT等训练
* 支持CV 目标检测/分割/分类等训练
* 支持NLP 文本分类/生成/理解等训练
* 由 1 个 Orchestrator + 8 个专职子智能体(Scenario-Analysis / Dataset-Analysis / Model-Selection / Training-Plan / Trainer / Monitor / Evaluator / Knowledge-Update)组成，角色定义见各模块目录下的 `AGENT.md`，路由规则见根目录 `AGENTS.md`/`SKILL.md`
* 无独立 Git-Ops 角色：候选方案以独立配置文件而非 git commit 做版本管理，keep/discard 决策与账本记录由 Evaluator Agent 承担
* 支持 codex / opencode / cursor / windsurf 四种执行引擎适配，见 `engines/`
