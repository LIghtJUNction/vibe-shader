# Changelog

## 0.2.0 — Establish the vibe

### Identity

- 项目统一使用 `vibe-shader` 名称，画面氛围与 vibe coding 成为同一套视觉概念。
- 新增 Natural、Golden Hour、Dreamwave、Night Drive 四种 Vibe Mode。
- 新增沿方块网格传播的 Code Pulse 与统一的双重强调色系统。

### Rendering

- 水和玻璃使用 `colortex4 + colortex7` 保存最近表面，并在 `colortex3` 累积更远的透明层，由 Composite 恢复背景后单次着色最近表面。
- 重写水体厚度吸收、折射、反射、焦散、泡沫和清澈度控制；重叠玻璃与玻璃后的水体不再直接丢层。
- 强化染色玻璃的颜色与透射衰减，深色玻璃不再近似全透明。
- 重写距离雾和低地薄雾，减弱白天整屏青色覆盖。
- 重写主世界天空、高空卷云和体积云照明，并移除卷云方位角接缝。
- 方块边缘改用带导数补偿的世界空间边缘函数，远近景更稳定。
- 新增代码脉冲、暮光联动边缘色和低天空光增强。
- 后期调色与 Vibe Mode 联动，降低色差和暗角。

### Stability

- High 默认关闭 TAA。
- TAA 新增水、玻璃、云、雨和水下 reactive mask。
- 收紧历史深度容差和颜色夹取范围，降低透明表面拖影。
- 保留 v0.1.1 的 Iris attribute collision 修复，公共顶点程序继续禁止 `ftransform()`。
- 包审计与发布工具共用稳定版 SemVer 规则，不再出现预发布版本审计通过但发布失败的情况。

### Repository

- `manifest.json` 更新至 0.2.0，并保留 Minecraft Java Edition 26.2+ / Iris 发布目标。
- README 更新 Vibe Mode、XMCL 安装、性能建议、验证边界与自动发布说明。
- 继续兼容仓库现有的 GitHub Release / CurseForge 自动发布工作流。

## 0.1.1 — Iris attribute collision fix

- 移除公共顶点程序中的 `ftransform()`。
- 修复部分驱动下 `iris_Position` 与 `gl_Vertex` 占用同一 attribute location 的链接错误。
