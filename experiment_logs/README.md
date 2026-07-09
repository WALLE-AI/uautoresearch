# 实验日志与结果账本

* `run.log` / `monitor.log` / `metrics.csv` / `experiment_results.csv` 的统一格式约定，见 `SKILL.md`
* 本目录无独立 Agent 角色：Trainer Agent 写 `run.log`，Monitor Agent 写 `monitor.log`/`metrics.csv`，Evaluator Agent 写 `experiment_results.csv`（keep/discard/PASS-FAIL 判定，见 `benchmark/AGENT.md`）
* 候选方案以独立配置文件（`config_path`）而非 git commit 做版本溯源，无回滚步骤
* swanlab/wandb 等外部日志平台的对接，按需在各 `trainer/references/<engine>.md` 中说明

