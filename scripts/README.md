# 训练脚本
* `<engine>_run.sh`：单次训练启动包装脚本，规范见 `SKILL.md`
* `loop_driver_template.sh`：Phase 3 并行循环驱动模板（多候选/多GPU场景），逐候选独立 commit + 独立 keep/discard，复制到 `scenarios/<tag>/` 后按需填写
