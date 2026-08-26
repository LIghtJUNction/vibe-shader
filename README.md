# vibe-shader

`vibe-shader` 是面向 Minecraft Java Edition、以 Iris 为主要目标的原创 Shader Pack。名字同时指画面的氛围感与 vibe coding：它不会把方块世界简单套上一层写实滤镜，而是用统一的天空、暮光、水体和各维度大气构成可辨认的视觉语言。

当前版本：**0.2.1**

发布目标：**Minecraft Java Edition 26.2+ / Iris**

## 0.2.1：运行时修复

- 修复 Iris 1.11.2 下光影包及设置页无法打开的问题。
- 移除体素描边及 Code Pulse，方块恢复自然材质边界。
- 新增基于真实场景深度的远景失焦、轻微散光和低照度视觉噪声；HUD 与近处手持物保持清晰。
- 新增晴天暖调、雨天阴沉、夜间视力衰减，以及低血量、饥饿和受伤时的动态视觉反馈。
- 新增自然地形衔接：连续的世界空间材质变化和远景纹理过滤减弱方块之间的割裂感，且不恢复描边。
- 加强空气透视、低地薄雾、晴雨色温与 Dreamwave 默认强度。
- 将人眼模糊、散光、Bloom 与 SSAO 的主要采样数降低约 25%–50%，并改进 FXAA 的亚像素边缘覆盖。
- 体积云改用双层快速噪声和单次粗略光照探针，High 档步数由 14 降至 12，避免每个步进重复执行两组四层 3D FBM。
- High 档体积光积分由 9 步降至 6 步，同时小幅提高光柱密度，保持氛围强度。
- 普通方块改为漫反射优先的磨砂响应：提高石土木植被粗糙度、压低非金属镜面和湿地反射，发光矿物默认关闭。
- 石材、土壤/陶瓦、木材、砂岩和雪新增独立材质分类；High/Cinematic 使用贴图亮度导出的双采样微表面法线、凹陷遮蔽与粗糙度变化，Low 自动关闭以节省性能。
- 新增边缘门控的方块圆润光照：只在真实法线/深度转折处混合相邻面的法线，平坦方块接缝不处理，不恢复彩色描边。
- 抬高洞穴间接光与 AO 下限，方块光改为全光谱暖光；后期减少统一双色染色并做保亮度色彩分离，避免大片方块挤成同一种橙色或蓝色。
- HDR 层次改用局部亮度对比与受控高光峰值，而不是泛白 Bloom；夜间月光高光增强，同时保留暗部纹理与材质色。
- 水体取消顶点位移造成的三角折面，降低 SSR、折射、太阳闪点、焦散与岸边泡沫；深水保留厚度吸收，垂直瀑布按薄水膜处理并使用连续向下流动法线，避免乳白或蓝色实墙。
- Bloom 只接收真正超过 1.05 HDR 亮度的光源，High 默认强度降至 `0.40`；太阳、水、玻璃及真实发光方块仍保留受控高光。
- 修复极光使用经度 `atan` 导致的垂直方位角接缝，改用连续天空平面投影。
- 情境氛围按环境分化：无光夜晚与低血量偏恐怖，夜间方块光源形成暖色庇护，晴天温暖，雨天阴冷。
- 为独立缓冲混合增加兼容回退。

## 0.2.0：建立真正的 Vibe

这一版重写了最影响观感和稳定性的几条渲染路径：

- 新增 Natural、Golden Hour、Dreamwave、Night Drive 四种 Vibe Mode，默认使用 **Dreamwave**。
- 水和玻璃改为先写入独立几何、颜色与类型缓冲，再由 Composite 统一计算折射、反射、厚度吸收、焦散和岸边泡沫，避免旧版透明颜色重复叠加。
- High 默认关闭 TAA；即使手动开启，水、玻璃、云、天气和水下画面也进入 reactive path，降低方块状拖影。
- 重写距离雾与低地薄雾，远景保留空气透视，白天不会被整屏青色覆盖。
- 重写主世界天空、暮光色带、高空卷云、月光、星空、极光与体积云照明。
- 后期调色跟随 Vibe Mode，在青蓝阴影、洋红暮光和暖金高光之间建立稳定层次，并降低旧版过强的色差和暗角。

## 安装

1. 安装适合当前 Minecraft Java 版本的 Iris 与 Sodium。OptiFine 仅保留传统目录布局兼容路径，当前没有完成客户端实机验证。
2. 从 [GitHub Releases](https://github.com/LIghtJUNction/vibe-shader/releases) 或 [CurseForge](https://www.curseforge.com/minecraft/shaders/vibe-shader) 下载 `vibe-shader-vX.Y.Z.zip`。
3. 将 ZIP 原样放入 `.minecraft/shaderpacks/`，不要解压。
4. 在“视频设置 → Shader Packs”中选择 `vibe-shader`。
5. 首次建议使用 `Vibe (Recommended)` 档。

XMCL 中可以选中实例，进入“资源管理 → 光影包”，直接拖入 ZIP。压缩包第一层应直接包含：

```text
shaders/
pack.png
LICENSE
```

## 推荐设置

### 日常游玩

```text
Profile: Vibe (Recommended)
Vibe Mode: Dreamwave
TAA: Off
FXAA: On
Cloud Quality: High
Water Quality: High
Water Opacity: 0.58
Water Clarity: 0.65
SSR: 16 steps
Distant Focus Loss: On
Subtle Astigmatism: On
Survival Vision Response: On
Natural Terrain Cohesion: On
Procedural Surface Relief: On
Rounded Block Lighting: On
Block Roundness: 0.40
Bloom Strength: 0.40
Emissive Ores: Off
```

### 截图

```text
Profile: Cinematic
Vibe Mode: Dreamwave / Golden Hour
TAA: 可开；移动镜头时仍建议关闭
Cloud Quality: Extreme
Water Quality: Cinematic
SSR: 26 steps
```

### 性能不足

优先降低：`Volumetric Cloud Quality` → `Screen-space Reflections` → `Procedural Surface Relief` → `Distant Focus Loss` → `Shadow Distance` → `Shadow Quality`。Vibe 调色本身开销较低。

## 人眼视觉与生存反馈

- 远景失焦使用四采样深度感知滤波与场景 mip，不会把近处方块轮廓、手持物或 HUD 一并抹糊。
- 散光只拉伸高亮能量，白天非常轻微，夜间光源附近更明显；原有彩色镜头鬼影与胶片颗粒已移除。
- 晴朗白天偏暖且最清晰；降雨会降低饱和度、色温与局部对比；无光夜晚会压低暖色和中间调，方块光源充足的夜间区域则转为明显的暖色庇护氛围。
- 低血量触发去饱和、脉搏式周边视野收缩与模糊；低饥饿触发低幅度眩晕；`is_hurt`、失明和黑暗状态会加强眩晕与失焦。
- Iris 1.11.2 没有单独暴露“中毒”状态 uniform，因此中毒通过其周期性受伤事件触发生理反馈；Shader Pack 无法在不安装配套模组的情况下把中毒与其他持续伤害完全区分。

所有视觉反馈默认开启，可在 **Human Vision / 人眼视觉** 页面分别关闭或调低强度。地形衔接可在 **Lighting / 光照** 页面调整；它只做连续调色和远景纹理过滤，不改变方块几何或碰撞体。

## Vibe Mode

- **Natural**：克制的蓝天和暖光，接近 Vanilla+。
- **Golden Hour**：更强的暖色阳光和低饱和阴影，适合建筑、村庄与截图。
- **Dreamwave**：默认风格，青蓝阴影、洋红暮光、暖金高光。
- **Night Drive**：深蓝夜景、橙红光源与更鲜明的冷暖反差。

## 三个维度

- **Overworld**：动态昼夜天空、暮光、体积云、雨天湿润反射与透明水体。
- **Nether**：程序化烟层、岩浆能量脉络、热雾和漂浮火星。
- **End**：星云、奇点吸积环、双向能量喷流与冷紫色体素氛围。

## 兼容范围与验证边界

- 使用 GLSL 330 compatibility，发布目标为 Minecraft Java Edition 26.2+ / Iris 管线。
- 保留 OptiFine 的 `world0`、`world-1`、`world1` 目录布局。
- 默认配置 90 / 90 组顶点—片元程序通过桌面 OpenGL 编译与链接。
- Low、Medium、High、Cinematic 代表分支 64 / 64 组通过编译与链接。
- 公共顶点程序中不存在 `ftransform()`，保留针对 Iris `iris_Position` / `gl_Vertex` attribute 冲突的防护。
- 已在 Minecraft 26.2、Fabric、Iris 1.11.2 与 Sodium 的实际客户端中反复加载测试；离线编译仍不能覆盖其他显卡驱动、资源包与模组组合。
- Distant Horizons 专用 `dh_*` pass 暂未实现，启用 DH 时远景不会获得完整材质模型。

完整测试范围见 [`VALIDATION.md`](VALIDATION.md)，版本变化见 [`CHANGELOG.md`](CHANGELOG.md)。

## 自动发布

GitHub Actions 中的 `Publish release` 工作流会执行包结构审计、GLSL 编译、画质分支验证，随后生成 `vibe-shader-vX.Y.Z.zip`、SHA-256 校验文件和 GitHub Release，并可选上传到 CurseForge。

CurseForge 发布使用以下仓库配置：

- Secret：`CURSEFORGE_TOKEN`
- Variable：`CURSEFORGE_PROJECT_ID`
- Variable：`MINECRAFT_VERSIONS`，每行填写一个受支持的 Minecraft 版本

## 项目结构

```text
shaders/lib/       通用数学、材质、天空、云、水、阴影与 Vibe 系统
shaders/program/   G-buffer、Deferred、Composite、Final 程序
shaders/world*/    维度宏与程序入口
shaders/lang/      中英文设置名称
shaders.properties 画质档、设置页面与混合策略
tools/             静态审计、GLSL 编译和发布辅助脚本
```

## License

MIT License。可修改和发布衍生版本，但需保留许可证与作者信息。
