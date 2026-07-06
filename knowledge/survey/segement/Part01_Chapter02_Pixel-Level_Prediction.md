# Part01 · Chapter02：Pixel-Level Prediction 与 Dense Prediction
------------------------------------------------------------------------

# 1. Pixel-Level Prediction

Pixel-Level
Prediction（像素级预测）是语义分割的核心思想，即模型需要对图像中的**每一个像素**预测其所属类别，而不是仅输出整张图像的类别或目标框。

## 与分类、检测的区别

  任务                    输入    输出                   粒度
  ----------------------- ------- ---------------------- --------
  Image Classification    Image   Class                  Image
  Object Detection        Image   Bounding Box + Class   Object
  Semantic Segmentation   Image   Pixel Label            Pixel

------------------------------------------------------------------------

# 2. Dense Prediction

Dense
Prediction（密集预测）指网络对输入图像中的所有空间位置同时进行预测。

典型任务：

-   Semantic Segmentation
-   Depth Estimation
-   Surface Normal Estimation
-   Optical Flow

------------------------------------------------------------------------

# 3. 为什么分类网络不能直接用于分割？

传统分类网络包含：

    Image
      ↓
    Backbone
      ↓
    Global Average Pooling
      ↓
    Fully Connected
      ↓
    Class

全连接层会丢失空间位置信息，因此无法恢复每个像素的位置。

------------------------------------------------------------------------

# 4. FCN 的突破

FCN（Fully Convolutional Network）提出：

-   去掉全连接层
-   使用卷积替代 FC
-   使用转置卷积恢复分辨率
-   Skip Connection 融合浅层与深层特征

流程：

    Image
     ↓
    Backbone
     ↓
    Feature Map
     ↓
    1×1 Conv
     ↓
    Transpose Conv
     ↓
    Pixel Prediction

------------------------------------------------------------------------

# 5. Pixel Prediction Pipeline

1.  提取多尺度特征
2.  保留空间结构
3.  Decoder 上采样
4.  输出与输入同尺寸 Mask
5.  逐像素计算 Loss

------------------------------------------------------------------------

# 6. 常见 Loss

-   Cross Entropy
-   Dice Loss
-   IoU Loss
-   Focal Loss
-   Lovasz Loss

------------------------------------------------------------------------

# 7. 工程实践

常用框架：

-   MMSegmentation
-   Detectron2
-   MONAI
-   Segmentation Models PyTorch

------------------------------------------------------------------------

# 8. 推荐阅读论文

  模型        链接
  ----------- ----------------------------------
  FCN         https://arxiv.org/abs/1411.4038
  U-Net       https://arxiv.org/abs/1505.04597
  DeepLab     https://arxiv.org/abs/1606.00915
  SegFormer   https://arxiv.org/abs/2105.15203

------------------------------------------------------------------------

## 下一章预告

第三章将深入介绍 Encoder--Decoder 架构、Skip
Connection、多尺度特征融合，以及其在 U-Net、DeepLab、SegFormer
中的设计思想。
