# Part01 · Chapter03：Encoder--Decoder 架构

> 《Semantic Segmentation 全景综述（2014--2026）》第一卷第三章

------------------------------------------------------------------------

# 1. Encoder--Decoder 概述

Encoder--Decoder 是现代语义分割最经典的网络结构，其核心思想为：

-   **Encoder**：逐步降低空间分辨率，提取高层语义特征。
-   **Decoder**：逐步恢复空间分辨率，重建像素级预测结果。

整体流程：

``` text
Image
  │
  ▼
Encoder
  │
  ▼
Latent Feature
  │
  ▼
Decoder
  │
  ▼
Segmentation Mask
```

------------------------------------------------------------------------

# 2. Encoder 的作用

Encoder 通常由 CNN 或 Transformer Backbone 构成。

主要职责：

-   提取局部纹理
-   提取全局语义
-   增大感受野
-   降低特征尺寸

典型 Backbone：

  Backbone           应用模型
  ------------------ ------------------------
  VGG16              FCN、SegNet
  ResNet             DeepLab、PSPNet
  HRNet              HRNet、OCRNet
  Swin Transformer   Swin-UNet、Mask2Former
  MiT                SegFormer
  ViT                SETR、SAM

------------------------------------------------------------------------

# 3. Decoder 的作用

Decoder 将低分辨率语义特征恢复到输入图像大小。

常见方法：

-   Bilinear Upsampling
-   Transposed Convolution
-   Pixel Shuffle
-   Feature Pyramid Fusion
-   MLP Decoder
-   Transformer Decoder

------------------------------------------------------------------------

# 4. Skip Connection

Skip Connection 用于融合浅层细节信息与深层语义信息。

``` text
Encoder Stage1 ─────────────┐
                            ▼
Encoder Stage2 ───────┐  Concat
                      ▼     │
Encoder Stage3 ──► Decoder ─┘
```

优点：

-   保留边界信息
-   提高小目标分割精度
-   加快梯度传播

代表模型：

-   U-Net
-   U-Net++
-   DeepLabV3+
-   SegFormer（多尺度融合）

------------------------------------------------------------------------

# 5. 多尺度特征融合

常见策略：

  方法        代表模型     特点
  ----------- ------------ ------------------
  FPN         Mask R-CNN   自顶向下融合
  ASPP        DeepLabV3+   多空洞率卷积
  PPM         PSPNet       金字塔池化
  HR Fusion   HRNet        全程保持高分辨率

------------------------------------------------------------------------

# 6. 不同 Decoder 对比

  Decoder               模型          优势           局限
  --------------------- ------------- -------------- ----------------
  DeConv                FCN           简单           棋盘效应
  U-Net Decoder         U-Net         边界恢复优秀   参数较多
  ASPP + Decoder        DeepLabV3+    多尺度能力强   计算开销增加
  MLP Decoder           SegFormer     轻量、高效     依赖强 Encoder
  Transformer Decoder   Mask2Former   统一多任务     显存需求较高

------------------------------------------------------------------------

# 7. 工程实践建议

-   医学影像：U-Net / nnU-Net
-   工业缺陷：DeepLabV3+、SegFormer
-   自动驾驶：Mask2Former
-   建筑视觉：SegFormer + Grounded-SAM

------------------------------------------------------------------------

# 8. 推荐论文

  模型          论文
  ------------- ----------------------------------
  U-Net         https://arxiv.org/abs/1505.04597
  DeepLabV3+    https://arxiv.org/abs/1802.02611
  SegFormer     https://arxiv.org/abs/2105.15203
  Mask2Former   https://arxiv.org/abs/2112.01527

------------------------------------------------------------------------

## 下一章预告

第四章将介绍 Backbone 的演进，包括
AlexNet、VGG、ResNet、EfficientNet、Swin Transformer、ViT
等主干网络，以及它们在语义分割中的应用。
