# Changelog

## 0.2.0 — Establish the vibe

### Identity

- 项目统一使用 `vibe-shader` 名称，画面氛围与 vibe coding 成为同一套视觉概念。
- 新增 Natural、Golden Hour、Dreamwave、Night Drive 四种 Vibe Mode。
- 新增沿方块网格传播的 Code Pulse 与统一的双重强调色系统。

### Rendering

- 水和玻璃从旧的颜色预混合路径迁移到 `colortex4 + colortex7` 元数据路径，由 Composite 单次完成着色。
- 重写水体厚度吸收、折射、反射、焦散、泡沫和清澈度控制。
- 重写距离雾和低地薄雾，减弱白天整屏青色覆盖。
- 重写主世界天空、高空卷云和体积云照明。
- 方块边缘改用带导数补偿的世界空间边缘函数，远近景更稳定。
- 新增代码脉冲、暮光联动边缘色和低天空光增强。
- 后期调色与 Vibe Mode 联动，降低色差和暗角。

### Stability

- High 默认关闭 TAA。
- TAA 新增水、玻璃、云、雨和水下 reactive mask。
- 收紧历史深度容差和颜色夹取范围，降低透明表面拖影。
- 保留 v0.1.1 的 Iris attribute collision 修复，公共顶点程序继续禁止 `ftransform()`。
- 包审计改为验证项目名与通用语义化版本号，不再把 CI 固定在单一版本。

### Repository

- `manifest.json` 更新至 0.2.0，并保留 Minecraft Java Edition 26.2+ / Iris 发布目标。
- README 更新 Vibe Mode、XMCL 安装、性能建议、验证边界与自动发布说明。
- 继续兼容仓库现有的 GitHub Release / CurseForge 自动发布工作流。

## 0.1.1 — Iris attribute collision fix

- 移除公共顶点程序中的 `ftransform()`。
- 修复部分驱动下 `iris_Position` 与 `gl_Vertex` 占用同一 attribute location 的链接错误。
