# Part01 · Chapter06：Attention 与 Transformer 基础

------------------------------------------------------------------------

# 1. 为什么需要 Attention？

传统 CNN 主要依赖局部卷积感受野，对于长距离依赖建模能力有限。

Attention 的目标是：

-   建立全局上下文关系
-   动态关注重要区域
-   提升复杂场景理解能力

------------------------------------------------------------------------

# 2. Attention 发展历程

``` text
SE
 ↓
CBAM
 ↓
Non-local
 ↓
Self-Attention
 ↓
Multi-Head Attention
 ↓
Vision Transformer
 ↓
Swin Transformer
```

------------------------------------------------------------------------

# 3. SE（Squeeze-and-Excitation）

核心思想：

-   Global Average Pooling
-   Channel Weight Learning
-   Channel Re-weighting

特点：

-   参数少
-   易于集成
-   提升通道表达能力

论文：

https://arxiv.org/abs/1709.01507

------------------------------------------------------------------------

# 4. CBAM

同时建模：

-   Channel Attention
-   Spatial Attention

流程：

``` text
Feature
 │
 ├── Channel Attention
 │
 └── Spatial Attention
      │
      ▼
 Refined Feature
```

论文：

https://arxiv.org/abs/1807.06521

------------------------------------------------------------------------

# 5. Non-local Network

建立任意位置之间的依赖关系：

``` text
Output(i)=Σ Softmax(QKᵀ)V
```

适用于：

-   视频理解
-   语义分割
-   姿态估计

论文：

https://arxiv.org/abs/1711.07971

------------------------------------------------------------------------

# 6. Self-Attention

流程：

``` text
Input
 │
 ├── Q
 ├── K
 └── V
      │
      ▼
Attention(Q,K,V)
```

优点：

-   全局建模
-   长距离依赖
-   可并行计算

------------------------------------------------------------------------

# 7. Multi-Head Attention

多个 Head 学习不同特征空间：

``` text
Input
 │
 ├── Head1
 ├── Head2
 ├── Head3
 └── HeadN
      │
      ▼
Concat
```

------------------------------------------------------------------------

# 8. Vision Transformer（ViT）

流程：

``` text
Image
 │
 ▼
Patch Embedding
 │
 ▼
Transformer Encoder
 │
 ▼
Feature Tokens
```

特点：

-   Patch Token 化
-   全局注意力
-   大规模预训练

论文：

https://arxiv.org/abs/2010.11929

------------------------------------------------------------------------

# 9. Swin Transformer

创新：

-   Window Attention
-   Shifted Window
-   Hierarchical Design

优势：

-   计算复杂度更低
-   更适合高分辨率视觉任务

论文：

https://arxiv.org/abs/2103.14030

------------------------------------------------------------------------

# 10. 在语义分割中的应用

  模型          Attention 类型
  ------------- ----------------------------------
  DANet         Dual Attention
  OCRNet        Object Context
  SegFormer     Multi-scale Transformer
  Mask2Former   Cross Attention + Mask Attention
  SAM           Prompt Attention

------------------------------------------------------------------------

# 11. CNN 与 Transformer 对比

  维度         CNN    Transformer
  ------------ ------ -------------
  感受野       局部   全局
  参数共享     是     是
  长距离依赖   较弱   强
  数据需求     较低   较高
  可扩展性     高     高

------------------------------------------------------------------------

# 12. 工程建议

-   小数据集：CNN 或 CNN+Attention
-   中大型数据集：SegFormer
-   多任务分割：Mask2Former
-   零样本分割：SAM / SAM2

------------------------------------------------------------------------

# 13. 推荐论文

  模型                 链接
  -------------------- ----------------------------------
  SE                   https://arxiv.org/abs/1709.01507
  CBAM                 https://arxiv.org/abs/1807.06521
  Non-local            https://arxiv.org/abs/1711.07971
  Vision Transformer   https://arxiv.org/abs/2010.11929
  Swin Transformer     https://arxiv.org/abs/2103.14030
  SegFormer            https://arxiv.org/abs/2105.15203

------------------------------------------------------------------------

## 下一章预告

第七章将介绍语义分割评价指标（PA、MPA、IoU、mIoU、Dice、Boundary
IoU）以及 Pascal VOC、Cityscapes、ADE20K、COCO Stuff、SA-1B
等主流数据集。
