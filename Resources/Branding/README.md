# Brand artwork / 品牌图形

`AppIcon.svg` and `StatusBarIcon.svg` are the original supplied vector artwork.
The PDFs in `Resources/` preserve those vectors and are checked in, so building
HoverCapture needs only Apple's Command Line Tools.

To regenerate the PDFs after editing the SVGs, use an existing `rsvg-convert`
installation from the repository root:

```sh
rsvg-convert --format pdf Resources/Branding/AppIcon.svg --output Resources/AppIcon.pdf
rsvg-convert --format pdf Resources/Branding/StatusBarIcon.svg --output Resources/StatusBarIconTemplate.pdf
```

The app icon build renders all ICNS sizes with an 80-point inset on a 1024-point
canvas. The menu icon remains a vector, is displayed at 18 points high with its
original aspect ratio, and uses the macOS template treatment for light and dark
menu bars. The README banner is the supplied `docs/assets/readme-banner.png`.

这两个 SVG 是原始设计稿。`Resources/` 中提交的 PDF 保留矢量图形，正常构建不需要安装
额外工具；修改 SVG 后，可使用已安装的 `rsvg-convert` 运行上面的命令重新导出。
应用图标沿用 1024 点画布、四周 80 点留白；状态栏图标保持原比例，以 18 点高度显示，
通过 macOS 模板图像自动适配深浅色菜单栏。README 横幅使用提供的原始 PNG。
