# Part01 · Chapter05：多尺度特征融合（Multi-scale Feature Fusion）

> 《Semantic Segmentation 全景综述（2014--2026）》第一卷第五章

------------------------------------------------------------------------

# 1. 为什么需要多尺度特征融合？

语义分割需要同时识别：

-   大目标（道路、建筑）
-   小目标（裂缝、螺栓、行人）
-   精细边界（轮廓、边缘）

浅层特征拥有较高分辨率但语义弱，深层特征拥有较强语义但空间细节不足，因此需要进行多尺度融合。

------------------------------------------------------------------------

# 2. 多尺度融合发展路线

``` text
Skip Connection (FCN/U-Net)
        │
        ▼
Feature Pyramid Network (FPN)
        │
        ▼
Pyramid Pooling Module (PSPNet)
        │
        ▼
Atrous Spatial Pyramid Pooling (DeepLabV3+)
        │
        ▼
HRNet Fusion
        │
        ▼
BiFPN
        │
        ▼
Transformer Multi-scale Fusion
```

------------------------------------------------------------------------

# 3. Skip Connection

核心思想：融合浅层细节与深层语义。

``` text
Encoder ───────┐
               ▼
           Concatenate
               ▼
Decoder
```

代表模型：

-   FCN
-   U-Net
-   U-Net++

优点：

-   恢复边缘信息
-   提升小目标分割

------------------------------------------------------------------------

# 4. Feature Pyramid Network（FPN）

特点：

-   Top-Down Pathway
-   Lateral Connection
-   多尺度特征统一输出

``` text
C5 → P5
│
├──► P4
│
├──► P3
│
└──► P2
```

应用：

-   Mask R-CNN
-   Panoptic FPN

------------------------------------------------------------------------

# 5. Pyramid Pooling Module（PPM）

PSPNet 提出金字塔池化。

``` text
Feature
 │
 ├── 1×1 Pool
 ├── 2×2 Pool
 ├── 3×3 Pool
 └── 6×6 Pool
      │
      ▼
Concat
```

优势：

-   获取全局上下文
-   提升场景理解能力

------------------------------------------------------------------------

# 6. Atrous Spatial Pyramid Pooling（ASPP）

DeepLabV3/V3+ 核心模块。

不同空洞率卷积：

-   rate=6
-   rate=12
-   rate=18
-   rate=24

共同提取不同尺度感受野。

------------------------------------------------------------------------

# 7. HRNet Fusion

HRNet 全程保持高分辨率。

特点：

-   多分辨率并行
-   持续跨尺度交换信息
-   边界恢复优秀

------------------------------------------------------------------------

# 8. BiFPN

EfficientDet 提出。

特点：

-   双向融合
-   Learnable Weight
-   更高融合效率

------------------------------------------------------------------------

# 9. Transformer 多尺度融合

典型模型：

-   SegFormer
-   Mask2Former
-   OneFormer

方法：

-   多尺度 Token
-   Cross Attention
-   Pixel Decoder

------------------------------------------------------------------------

# 10. 方法对比

  方法                 代表模型     优势         局限
  -------------------- ------------ ------------ ----------------
  Skip Connection      U-Net        简洁高效     全局上下文不足
  FPN                  Mask R-CNN   多尺度统一   语义融合有限
  PPM                  PSPNet       全局上下文   参数增加
  ASPP                 DeepLabV3+   多感受野     空洞卷积开销
  HR Fusion            HRNet        边界精细     网络复杂
  Transformer Fusion   SegFormer    全局建模     显存需求较高

------------------------------------------------------------------------

# 11. 工程建议

-   医学：U-Net + Skip
-   自动驾驶：DeepLabV3+ / Mask2Former
-   建筑视觉：SegFormer + ASPP
-   遥感：HRNet / PSPNet

------------------------------------------------------------------------

# 12. 推荐论文

  模块         论文
  ------------ ----------------------------------
  FPN          https://arxiv.org/abs/1612.03144
  PSPNet       https://arxiv.org/abs/1612.01105
  DeepLabV3    https://arxiv.org/abs/1706.05587
  DeepLabV3+   https://arxiv.org/abs/1802.02611
  HRNet        https://arxiv.org/abs/1904.04514
  SegFormer    https://arxiv.org/abs/2105.15203

------------------------------------------------------------------------

## 下一章预告

第六章将介绍 Attention 与 Transformer 基础，包括
Self-Attention、Multi-Head Attention、Window Attention、Cross Attention
及其在现代语义分割中的应用。
