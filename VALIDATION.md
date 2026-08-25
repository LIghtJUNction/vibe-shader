# vibe-shader — 验证报告

生成日期：2026-08-26  
版本：0.1.1

## 已完成验证

### 默认配置全程序验证

- 展开所有 `#include`。
- 检查 `#version` 是否位于每个入口文件第一行。
- 检查条件编译指令是否闭合。
- 编译并链接 `world0`、`world-1`、`world1` 中全部 90 组顶点/片元程序。
- 结果：**90 / 90 通过，0 失败**。

### 四档配置分支验证

对 Low、Medium、High、Cinematic 四档，分别替换数值宏与功能开关，并覆盖三个维度的代表性路径：

- `gbuffers_terrain`
- `gbuffers_water`
- `deferred`
- `composite`
- `final`
- Overworld `shadow`

结果：**64 / 64 通过，0 失败**。

### Iris 顶点属性冲突回归检查

- 扫描所有顶点入口及公共顶点程序，确保不存在 `ftransform()` 调用。
- `gl_Vertex` 只以 Iris 可直接重写的显式表达式形式出现。
- 目的：避免 Iris 生成 `iris_Position` 后，驱动仍从辅助 `ftransform` 实现中检测到内建 `gl_Vertex`，从而产生 attribute 0 冲突。

### 验证环境

```text
OpenGL: 4.5 (Compatibility Profile) Mesa 25.0.7-2
Shader language: GLSL 330 compatibility
Headless context: EGL surfaceless / pbuffer
```

原始输出保存在：

- `validation_run.log`
- `profile_validation_run.log`

验证脚本位于：

- `tools/validate_glsl.py`
- `tools/validate_profiles.py`

## 验证边界

上述结果证明源码在测试环境中能够完成 GLSL 编译和程序链接，也证明 include、入口配对和主要条件编译分支保持结构完整。

当前运行环境没有 Minecraft Java 客户端、Iris 渲染器和真实世界存档，因此仍未完成以下验证：

- 实际游戏内加载和逐帧渲染；
- 不同 Iris、Sodium、OptiFine 与 Minecraft 版本组合；
- NVIDIA、AMD、Intel 和 Apple 驱动差异；
- 第三方资源包、模组方块、模组维度和实体兼容；
- 长时间运行中的显存占用、TAA 历史稳定性和性能数据；
- Distant Horizons 专用 `dh_*` 管线。

第一次进入游戏时建议先使用 `Medium`，在原版资源包和 Overworld 白天场景中确认阴影、水体、天空与透明方块均正常，再逐项提高质量。
