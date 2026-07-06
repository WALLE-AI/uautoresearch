# 第一卷：语义分割基础（第1章）

# 1. 图像分割概述

## 1.1 什么是图像分割

图像分割（Image
Segmentation）是计算机视觉中的核心任务，其目标是为图像中的每一个像素赋予语义标签。

与图像分类、目标检测相比：

  任务   输出
  ------ --------------
  分类   图像类别
  检测   Bounding Box
  分割   Pixel Mask

------------------------------------------------------------------------

## 1.2 三种主流分割任务

### Semantic Segmentation

同类别目标共享一个类别 ID。

### Instance Segmentation

同类别不同实例分别预测。

### Panoptic Segmentation

统一语义分割与实例分割。

------------------------------------------------------------------------

## 1.3 技术发展路线

``` text
GraphCut
   ↓
FCN
   ↓
U-Net
   ↓
DeepLab
   ↓
PSPNet
   ↓
HRNet
   ↓
SETR
   ↓
SegFormer
   ↓
Mask2Former
   ↓
SAM
   ↓
SAM2
```

------------------------------------------------------------------------

## 1.4 常用评价指标

-   Pixel Accuracy (PA)
-   Mean Pixel Accuracy (MPA)
-   IoU
-   mIoU
-   Dice
-   Boundary IoU

------------------------------------------------------------------------

## 1.5 主流数据集

  数据集       应用
  ------------ --------------
  Pascal VOC   通用语义分割
  ADE20K       场景理解
  Cityscapes   自动驾驶
  COCO Stuff   全景分割
  LoveDA       遥感
  Crack500     裂缝检测
  SA-1B        SAM 训练

------------------------------------------------------------------------

## 1.6 推荐论文

-   FCN: https://arxiv.org/abs/1411.4038
-   U-Net: https://arxiv.org/abs/1505.04597
-   DeepLab: https://arxiv.org/abs/1606.00915
-   SegFormer: https://arxiv.org/abs/2105.15203
-   Mask2Former: https://arxiv.org/abs/2112.01527
-   SAM: https://arxiv.org/abs/2304.02643
-   SAM2: https://arxiv.org/abs/2408.00714

------------------------------------------------------------------------

> 下一章节将详细介绍 Pixel-level Prediction、Dense Prediction 与 FCN
> 的理论基础。
