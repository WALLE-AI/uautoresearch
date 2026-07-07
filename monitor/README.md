# Monitor

巡检 Phase 3 训练中的候选：定期记录 loss/评测指标/GPU利用率与显存到 `experiment_logs/<tag>/runs/<candidate>/metrics.csv` + `monitor.log`，并对基础异常（loss=nan/inf、GPU长时间空闲疑似卡死）显式告警。只读观察，不修改训练配置、不终止进程。

角色定义见 `AGENT.md`，具体巡检逻辑见 `SKILL.md`。
