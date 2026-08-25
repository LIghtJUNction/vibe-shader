# vibe-shader

`vibe-shader` 是面向 Minecraft Java Edition、以 Iris 为主要目标的原创 Shader Pack。名字同时指画面的氛围感与 vibe coding：它不会把方块世界简单套上一层写实滤镜，而是用统一的天空、暮光、水体、体素边缘与“代码脉冲”构成可辨认的视觉语言。

当前版本：**0.2.0**  
发布目标：**Minecraft Java Edition 26.2+ / Iris**

## 0.2.0：建立真正的 Vibe

这一版重写了最影响观感和稳定性的几条渲染路径：

- 新增 Natural、Golden Hour、Dreamwave、Night Drive 四种 Vibe Mode，默认使用 **Dreamwave**。
- 新增世界空间体素边缘和沿方块网格传播的 **Code Pulse**，让建筑、悬崖、洞穴和低光区域形成统一的视觉节奏。
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
SSR: 16 steps
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

优先降低：`Volumetric Cloud Quality` → `Screen-space Reflections` → `Shadow Distance` → `Shadow Quality`。体素边缘、Code Pulse 和 Vibe 调色本身开销较低。

## Vibe Mode

- **Natural**：克制的蓝天和暖光，接近 Vanilla+。
- **Golden Hour**：更强的暖色阳光和低饱和阴影，适合建筑、村庄与截图。
- **Dreamwave**：默认风格，青蓝阴影、洋红暮光、暖金高光。
- **Night Drive**：深蓝夜景、橙红光源与更明显的代码脉冲。

## 三个维度

- **Overworld**：动态昼夜天空、暮光、体积云、雨天湿润反射、透明水体与 Code Pulse。
- **Nether**：程序化烟层、岩浆能量脉络、热雾和漂浮火星。
- **End**：星云、奇点吸积环、双向能量喷流与冷紫色体素氛围。

## 兼容范围与验证边界

- 使用 GLSL 330 compatibility，发布目标为 Minecraft Java Edition 26.2+ / Iris 管线。
- 保留 OptiFine 的 `world0`、`world-1`、`world1` 目录布局。
- 默认配置 90 / 90 组顶点—片元程序通过桌面 OpenGL 编译与链接。
- Low、Medium、High、Cinematic 代表分支 64 / 64 组通过编译与链接。
- 公共顶点程序中不存在 `ftransform()`，保留针对 Iris `iris_Position` / `gl_Vertex` attribute 冲突的防护。
- 当前环境无法启动完整 Minecraft 客户端。离线编译不能替代 Iris、Sodium、显卡驱动、资源包与模组组合下的实际画面测试。
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
