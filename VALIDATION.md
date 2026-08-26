# vibe-shader 0.2.1 Validation

验证日期：2026-08-27

发布目标：Minecraft Java Edition 26.2+ / Iris

## 结果

```text
包结构审计：通过（0 failures）
默认程序：90 / 90 编译、链接通过
画质分支：64 / 64 编译、链接通过
Profile 配置契约：Low / Medium / High / Cinematic 全部匹配
OpenGL：4.6.0 NVIDIA 610.57.04
ftransform() 扫描：0 处
水体旧双重混合路径：0 处
透明层累积路径：colortex3
运行时：Minecraft 26.2 / Fabric / Iris 1.11.2 / Sodium 已加载
```

## 覆盖内容

- 递归展开所有 `#include`，检查缺失文件与 include 环。
- 检查预处理指令配对。
- 编译并链接 `world0`、`world-1`、`world1` 的全部顶点/片元组合。
- 对 Low、Medium、High、Cinematic 的代表性 G-buffer、Deferred、Composite、Final、Shadow 分支再次编译。
- 将 `shaders.properties` 中的四档 Profile 与验证器预期逐项对照，防止验证参数和实际菜单配置分离。
- 检查设置项具有中英文标签。
- 检查材质 ID 重复、必需目录、图标尺寸、项目名称与语义化版本号。
- 检查公共顶点程序中不存在 `ftransform()`，避免 Iris `iris_Position` / `gl_Vertex` attribute 冲突回归。
- 检查水体程序使用 `colortex4` 和 `colortex7` 保存最近表面，并通过 `colortex3` 的 straight-alpha 混合保存更远透明层；Composite 恢复背景后单次着色最近表面。
- 检查 Iris 清屏颜色使用四分量 `vec4`，独立缓冲混合具有不支持设备回退。
- 检查体素描边、Code Pulse、胶片颗粒和彩色镜头鬼影已移除。
- 检查深度感知人眼视觉、自然地形衔接、程序化表面起伏、边缘门控圆润光照、感知局部对比、优化体积云/体积光及磨砂材质路径存在。
- 检查极光不再使用存在方位角分支切口的 `atan` 映射。
- 检查水体保持平面几何，并使用厚度吸收、受控 SSR、垂直流动法线、垂直薄膜厚度上限与收敛的焦散/泡沫。
- 检查 `pack.png` 为 256 × 256，并验证发布包根目录结构。

## 运行时验证

- 首轮 v0.2.0 加载失败已由 Iris 1.11.2 实机日志定位为单参数 `colortex3ClearColor` 解析异常；0.2.1 改用四分量后，光影包及设置页可正常打开。
- Minecraft 26.2 客户端中已反复重新加载测试包，并检查昼夜、低血量/饥饿反馈、极光、洞穴材质和水体画面。
- 游戏内截图发现的体素描边、极光方位角接缝、过量泛光、单色化材质与水面平面折角均已进入自动回归检查或结构检查。

## 验证边界

离线 GLSL 编译不能覆盖所有显卡驱动、资源包、模组方块和运行时 framebuffer 组合。材质与水体的最终视觉接受仍以不同场景的游戏内截图和帧率测试为准。

Distant Horizons 专用 `dh_*` pass 尚未实现，不在本轮验证范围内。
