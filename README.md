# vibe-shader · Meridian

**天穹折光 / Meridian** 是本分支的实验性视觉重构。项目仍叫 `vibe-shader`，面向 Minecraft Java / Iris；没有重新加入体素描边、Code Pulse 或整屏彩色滤镜。

稳定发布历史仍为 **0.2.1**。本分支是尚待 Minecraft 实机验收的预览，不是已验证的新稳定版；`manifest.json` 暂保留稳定版本号。

## 这次能看到什么

**主世界：天穹丝带。** 日落后，世界固定方向上浮现细薄的香槟金与矿物色光带；低速折叠、局部断续，水面天空反射使用同一函数。不是随镜头移动的屏幕贴图。雨天遮去，地平线以下不直接绘制。

**夜海：局部微光。** 近处水平水面出现缓慢变化的稀疏发光纹理，而不是把整片水染亮。白天、远处、极薄水层、垂直瀑布与下界不产生此效果；末地保留。它是程序化材质，不依赖实体或额外资源包，也不是玩家接近触发的真实浮游生物模拟。

**末地：观测站。** 更大的暗核、分层吸积盘、偏转星光与上方弧光，颜色以象牙金和深矿物色为主。使用艺术化透镜近似，不宣称广义相对论光线追踪。暗核遮挡背景星光，背面不会复制一颗天体；雾色与天体分离，避免星环作为雾色透过地形。

新增默认 **Meridian** 调色，保留 Natural / Golden Hour / Dreamwave / Night Drive 四种旧模式。普通方块仍优先保留材质色和磨砂响应。

## 安装预览包

将 `vibe-shader-meridian-preview.zip` 原样放入实例的 `.minecraft/shaderpacks/`，不要解压。XMCL 可在实例“资源管理 → 光影包”拖入 ZIP，然后在游戏 Shader Packs 中选择它。第一层应直接包含 `shaders/`、`pack.png`、`LICENSE`。

沿用项目原有目标：Minecraft Java 26.2+ / Iris、GLSL 330 compatibility。OptiFine 仅保留目录与兼容回退路径，没有本次实机验收。Distant Horizons 专用 `dh_*` pass 尚未实现。

## 设置

首次使用 **High / Vibe (Recommended)**。Vibe Mode 默认为 **天穹折光 / Meridian**，TAA 仍默认关闭。天象控制在新的“天穹折光”设置页。

| 选项 | 默认 | 用途 |
| --- | --- | --- |
| 天象细节 | 2 / 观测站 | 0 关闭新天空天象；1 保留主效果；2 增加第二层丝带和末地弧光 |
| 天象强度 | 0.85 | 0 完全关闭新天空天象，不关闭独立的夜海微光 |
| 夜海微光 | 0.65 | 0 单独关闭；Low 档默认为 0 |
| 天象流速 | 0.35 | 0 冻结新增天象与微光的动画，不冻结原有水波、云、星光闪烁或昼夜 |

四个画质档均显式配置新选项。性能不足时优先调低体积云、SSR、阴影和新天象细节；当前没有可据以承诺帧率的游戏内 GPU 测量。

## 验证与复现

```sh
python tools/audit_pack.py
python tools/validate_glsl.py
python tools/validate_profiles.py
python -m unittest discover -s tools -p 'test_*.py' -v
python tools/render_preview.py --output dist/previews
```

验证需要 Linux Mesa/EGL 与桌面 OpenGL；审计及预览保存需要 Pillow。`render_preview.py` 直接执行仓库 GLSL，但只包含天空和示意水面，**不是 Minecraft 截图，不含完整地形、体积云、阴影和后期管线**。

本地：90 组默认程序、118 组画质/开关组合通过编译与链接；20 项回归测试通过，其中包含真实 RGBA32F 帧缓冲像素检查。CI 在分支推送和 PR 上重跑验证，并提供源码、可安装包、校验文件、离线预览和日志。

实机验收清单与边界见 [VALIDATION.md](VALIDATION.md)，设计和代码入口见 [docs/MERIDIAN.md](docs/MERIDIAN.md)。此前变化保存在 [CHANGELOG.md](CHANGELOG.md)。

## 发布与许可

原有手动 `Publish release` 流程保留。本次没有发布新稳定版、覆盖 CurseForge 包或合并到 main。MIT License，修改和分发须保留许可证及作者信息。
