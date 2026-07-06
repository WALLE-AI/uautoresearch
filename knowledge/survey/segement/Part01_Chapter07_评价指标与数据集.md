# Part01 · Chapter07：评价指标与数据集

## 1. 为什么需要评价指标

语义分割属于像素级预测任务，仅使用分类准确率无法全面反映模型质量，因此需要结合重叠度、边界质量、类别均衡等多个指标综合评价。近年来研究也指出，仅依赖单一
mIoU 存在对大目标偏置的问题。citeturn0search0turn0academia9

------------------------------------------------------------------------

## 2. 混淆矩阵

对于每个类别统计：

-   TP：预测正确的目标像素
-   FP：错误预测为目标
-   FN：漏检目标
-   TN：正确背景

所有评价指标均由此推导。

------------------------------------------------------------------------

## 3. 常见评价指标

### Pixel Accuracy（PA）

总体像素分类正确率。

### Mean Pixel Accuracy（MPA）

分别计算每个类别准确率后求平均。

### IoU

IoU = TP / (TP + FP + FN)

优点：最常用，适用于 VOC、Cityscapes、ADE20K
等数据集。citeturn0search3

### mIoU

所有类别 IoU 的平均值，是当前语义分割最主流 Benchmark
指标。citeturn0search3turn0search2

### Dice

Dice = 2TP / (2TP + FP + FN)

医学影像最常使用，与 IoU 高度相关。citeturn0search1turn0search3

### Boundary IoU / BF Score

更加关注边界预测质量，适用于裂缝检测、医学分割、建筑轮廓等任务。citeturn0search2

------------------------------------------------------------------------

## 4. 主流公开数据集

  数据集            场景               特点
  ----------------- ------------------ --------------------------
  Pascal VOC 2012   通用               20 类经典基准
  Cityscapes        自动驾驶           城市场景、高精标注
  ADE20K            场景理解           150 类，Transformer 常用
  COCO Stuff        通用               Stuff + Thing
  LoveDA            遥感               城乡遥感
  Crack500          工业裂缝           裂缝检测
  SA-1B             Foundation Model   SAM 训练数据集

------------------------------------------------------------------------

## 5. 不同领域推荐指标

  场景       推荐指标
  ---------- --------------------
  自动驾驶   mIoU、Class IoU
  医学       Dice、HD95
  工业缺陷   IoU、Boundary IoU
  建筑视觉   mIoU、Boundary IoU
  遥感       mIoU、F1

------------------------------------------------------------------------

## 6. 工程建议

-   不要只报告 PA。
-   至少同时报告 mIoU、Dice、Precision、Recall。
-   小目标任务增加 Boundary IoU。
-   医学场景建议 Dice + HD95。
-   新研究可增加 Fine-grained mIoU。citeturn0academia9turn0search0

------------------------------------------------------------------------

## 7. 推荐论文与资源

-   Revisiting Evaluation Metrics for Semantic Segmentation (NeurIPS
    2023)
-   Pascal VOC
-   Cityscapes
-   ADE20K
-   SA-1B

------------------------------------------------------------------------

## 下一章

第一卷总结：发展路线、算法演进、阅读路线图。
