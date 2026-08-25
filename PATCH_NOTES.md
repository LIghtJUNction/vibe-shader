# vibe-shader v0.1.1 patch notes

修复 Iris 加载阶段的顶点属性链接错误：

```text
Attribute iris_Position is bound to generic attribute 0, but gl_Vertex is also used
```

根因是多个公共顶点程序使用 `ftransform()`。Iris 会为现代顶点格式注入 `iris_Position`；在部分驱动或特定 line-program 转换路径中，`ftransform` 辅助实现仍可能保留内建 `gl_Vertex`，导致两者占用相同属性位置。

本版本将全部四处 `ftransform()` 改为显式矩阵乘法，并增加打包审计规则，防止该调用重新进入公共顶点程序。
