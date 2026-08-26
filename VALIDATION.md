# vibe-shader 0.2.0 Validation

验证日期：2026-08-26  
发布目标：Minecraft Java Edition 26.2+ / Iris

## 结果

```text
包结构审计：通过
默认程序：90 / 90 编译、链接通过
画质分支：64 / 64 编译、链接通过
OpenGL：4.5 Compatibility Profile / Mesa 25.0.7-2
ftransform() 扫描：0 处
水体旧双重混合路径：0 处
```

## 覆盖内容

- 递归展开所有 `#include`，检查缺失文件与 include 环。
- 检查预处理指令配对。
- 编译并链接 `world0`、`world-1`、`world1` 的全部顶点/片元组合。
- 对 Low、Medium、High、Cinematic 的代表性 G-buffer、Deferred、Composite、Final、Shadow 分支再次编译。
- 检查设置项具有中英文标签。
- 检查材质 ID 重复、必需目录、图标尺寸、项目名称与语义化版本号。
- 检查公共顶点程序中不存在 `ftransform()`，避免 Iris `iris_Position` / `gl_Vertex` attribute 冲突回归。
- 检查水体程序只写入 `colortex4` 和 `colortex7`，透明颜色由 Composite 单次着色。
- 检查 `pack.png` 为 256 × 256，并验证发布包根目录结构。

## 验证边界

本报告覆盖离线编译和静态结构验证，没有启动 Minecraft、Iris 或 Sodium，也没有模拟具体资源包、模组方块、显卡驱动补丁器和运行时 framebuffer 行为。实际兼容性与视觉质量仍以游戏内测试为准。

Distant Horizons 专用 `dh_*` pass 尚未实现，不在本轮验证范围内。
