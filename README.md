# vibe-shader

一个从零编写、以 Iris 为主要目标并保留 OptiFine 传统目录布局的 Minecraft Java Edition Shader Pack。目标是保留方块世界的识别度，同时提供高动态范围延迟光照、体积方块云、湿润反射、透明水体、发光矿物以及三个维度独立的天空表现。

## 核心效果

- Overworld：昼夜天空、日落散射、月相切口、星空、极光、体积方块云、太阳光柱、动态雨幕。
- Water：顶点水波、法线细节、厚度吸收、色散折射、Fresnel、屏幕空间反射与水下焦散。
- Materials：雨天湿润度、金属高光、矿石晶体脉冲、方块边缘强调、暖/冷发光方块。
- Nether：程序化烟层、岩浆色能量脉络和漂浮火星。
- End：程序化星云、奇点吸积环和双向能量喷流。
- Post：TAA 历史重投影、FXAA、多尺度 Bloom、横向光迹、轻微色差、ACES 映射、胶片颗粒。
- Quality：Low / Medium / High / Cinematic 四档，可单独调整关键效果。

## 安装

1. 安装适合当前 Minecraft Java 版本的 Iris + Sodium。OptiFine 仅作为保留传统目录布局的次要兼容路径，当前未进行实际客户端验证。
2. 从 [GitHub Releases](https://github.com/LIghtJUNction/vibe-shader/releases) 或 [CurseForge](https://www.curseforge.com/minecraft/shaders/vibe-shader) 下载 `vibe-shader-vX.Y.Z.zip`，原样放入 `.minecraft/shaderpacks/`，不要解压。
3. 进入“视频设置 → Shader Packs”，选择 `vibe-shader`。
4. 首次启动建议选择 `Medium`。确认稳定后再切换 `High` 或 `Cinematic`。

## v0.1.1 兼容性修复

- 移除了所有顶点程序中的 `ftransform()`。
- 改用显式 `gl_ProjectionMatrix * gl_ModelViewMatrix * gl_Vertex`，避免 Iris 转换后同时激活 `iris_Position` 与兼容模式 `gl_Vertex`。
- 该修复针对 `LINES: Attribute iris_Position ... gl_Vertex ... collided` 链接失败，也覆盖使用相同公共顶点程序的实体、手持物、粒子、天空、天气和全屏 Pass。

## 性能建议

- 核显 / 8 GB 系统内存：Low，阴影 96，关闭 SSR。
- 入门独显：Medium，1080p。
- 中高端独显：High，1080p 或 1440p。
- Cinematic 会使用 3072 阴影贴图、22 步云积分、26 步 SSR 与 13 步体积光，主要面向截图。

帧率过低时，优先降低：`Volumetric Cloud Quality` → `Screen-space Reflections` → `Shadow Distance` → `Shadow Quality`。

## 兼容范围与验证边界

- 采用 GLSL 330 compatibility，发布目标为 Minecraft Java 26.2 及更高版本 / Iris 管线。
- 结构保留 OptiFine 的 `world0`、`world-1`、`world1` 目录约定。
- 源码已进行离线 include 展开、预处理结构检查与桌面 OpenGL 编译/链接验证：默认配置 90 / 90 组程序通过，四档代表分支 64 / 64 组程序通过。
- 当前环境无法启动完整 Minecraft 客户端，因此没有声称完成真实游戏内兼容测试。不同资源包、模组方块、驱动和 Iris 版本仍可能暴露需要修补的材质映射或管线差异。
- Distant Horizons 专用 `dh_*` pass 暂未实现；启用 DH 时远景不会获得本包的完整材质模型。

## 验证报告

完整编译记录、测试范围与未覆盖边界见 `VALIDATION.md`。

## 自动发布

GitHub Actions 中的 `Publish release` 工作流会验证 Shader Pack、生成 ZIP、创建 GitHub Release，并可上传到 CurseForge。手动运行时可选择不改版本，或自动递增 patch、minor、major；也可以输入指定版本。

CurseForge 发布使用以下仓库配置：

- Secret：`CURSEFORGE_TOKEN`
- Variable：`CURSEFORGE_PROJECT_ID`
- Variable：`MINECRAFT_VERSIONS`，每行填写一个受支持的 Minecraft 版本

## 开发

所有实际实现位于 `shaders/lib/` 与 `shaders/program/`，维度目录中的 `.vsh/.fsh` 仅负责声明 GLSL 版本、维度宏与程序组合。`pack.png` 为选择界面图标。Shader Pack 使用 MIT License，可自由修改与发布衍生版本，但请保留许可证。
