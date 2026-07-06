# Part01 · Chapter04：Backbone 演进（Evolution of Backbone Networks）
------------------------------------------------------------------------

# 1. 什么是 Backbone？

Backbone
是视觉模型中的**特征提取网络**，负责从输入图像中学习不同层级的特征表示，为后续
Decoder 或检测头提供输入。

典型流程：

``` text
Image
  │
  ▼
Backbone
  │
  ├── Stage1（低层纹理）
  ├── Stage2（局部结构）
  ├── Stage3（高级语义）
  └── Stage4（全局语义）
  │
  ▼
Decoder / Head
```

------------------------------------------------------------------------

# 2. Backbone 演进路线

``` text
LeNet
  ↓
AlexNet
  ↓
VGG
  ↓
GoogLeNet
  ↓
ResNet
  ↓
DenseNet
  ↓
EfficientNet
  ↓
HRNet
  ↓
Vision Transformer (ViT)
  ↓
Swin Transformer
  ↓
MiT（SegFormer）
```

------------------------------------------------------------------------

# 3. 各代 Backbone 对比

  Backbone   核心创新              优点               常见分割模型
  ---------- --------------------- ------------------ ------------------------
  AlexNet    深度 CNN              开启深度学习时代   早期研究
  VGG16/19   小卷积堆叠            结构简单           FCN、SegNet
  ResNet     残差连接              可训练超深网络     DeepLab、PSPNet
  DenseNet   密集连接              特征复用           医学分割
  HRNet      多分辨率并行          边界精细           HRNet、OCRNet
  ViT        Patch + MHSA          全局建模           SETR、SAM
  Swin       Window Attention      高效层次化         Swin-UNet、Mask2Former
  MiT        无位置编码 + 多尺度   轻量高效           SegFormer

------------------------------------------------------------------------

# 4. CNN Backbone

## VGG

特点：

-   3×3 卷积
-   结构规则
-   参数量较大

应用：

-   FCN
-   SegNet

## ResNet

提出残差学习：

``` text
x ───────────────┐
 │               │
 ▼               │
Conv → BN → ReLU │
 │               │
 └──── Add ◄─────┘
```

优势：

-   缓解梯度消失
-   支持 50/101/152 层网络

------------------------------------------------------------------------

# 5. Transformer Backbone

## Vision Transformer（ViT）

流程：

``` text
Image
  ↓
Patch Embedding
  ↓
Transformer Encoder
  ↓
Feature Tokens
```

优势：

-   全局感受野
-   长距离依赖建模

局限：

-   数据需求大
-   计算量较高

------------------------------------------------------------------------

## Swin Transformer

创新：

-   Window Attention
-   Shifted Window
-   Hierarchical Feature

适用于：

-   Mask2Former
-   Swin-UNet

------------------------------------------------------------------------

## MiT（Mix Vision Transformer）

SegFormer 使用的主干网络。

特点：

-   多尺度输出
-   无绝对位置编码
-   轻量 Decoder

------------------------------------------------------------------------

# 6. Backbone 选型建议

  场景           推荐 Backbone
  -------------- ------------------
  医学影像       ResNet、DenseNet
  自动驾驶       Swin Transformer
  工业检测       ResNet、MiT
  建筑视觉       MiT、Swin
  开放词汇分割   ViT、Hiera

------------------------------------------------------------------------

# 7. 推荐论文

  模型                 论文
  -------------------- ----------------------------------
  ResNet               https://arxiv.org/abs/1512.03385
  HRNet                https://arxiv.org/abs/1904.04514
  Vision Transformer   https://arxiv.org/abs/2010.11929
  Swin Transformer     https://arxiv.org/abs/2103.14030
  SegFormer            https://arxiv.org/abs/2105.15203

------------------------------------------------------------------------

## 下一章预告

第五章将介绍多尺度特征融合，包括 FPN、PPM、ASPP、BiFPN、HR Fusion
等经典结构及其在语义分割中的应用。
