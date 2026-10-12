# Interface icons / 界面图标

HoverCapture uses a small selection from [Lucide](https://lucide.dev/icons/), chosen for its consistent 24 × 24 grid, 2-pixel strokes, and rounded line caps and joins. The shape language complements HoverCapture's window-and-pointer logo. Interface tinting uses the app's brand colors; the source artwork is unchanged.

HoverCapture 的界面采用 [Lucide](https://lucide.dev/icons/) 的少量图标：统一的 24 × 24 网格、2 像素线宽和圆角端点，与窗口和指针的品牌标志协调。界面通过模板图像应用品牌色，原始矢量路径保持不变。

## Source / 来源

- Upstream repository: [lucide-icons/lucide](https://github.com/lucide-icons/lucide).
- Pinned commit: [`70562c1ee1c4fdcf736fe97bc893fb8511927934`](https://github.com/lucide-icons/lucide/tree/70562c1ee1c4fdcf736fe97bc893fb8511927934).
- Original files: [`icons/`](https://github.com/lucide-icons/lucide/tree/70562c1ee1c4fdcf736fe97bc893fb8511927934/icons).
- Official design rules: [Lucide design language](https://lucide.dev/contribute/icons/design-principles).
- License: [Lucide license](https://lucide.dev/license); the complete upstream ISC and Feather MIT notices are preserved in [LICENSE](LICENSE).

| Local name / 本地名称 | Upstream SVG / 原始 SVG | Use / 用途 |
| --- | --- | --- |
| `folder-open` | `folder-open.svg` | Screenshot save folder / 截图保存目录 |
| `keyboard` | `keyboard.svg` | Capture shortcut / 截图快捷键 |
| `layers` | `layers.svg` | Screenshot queue / 连续截图队列 |
| `languages` | `languages.svg` | Interface language / 界面语言 |
| `shield-check` | `shield-check.svg` | Screen recording permission / 屏幕录制权限 |
| `check` | `check.svg` | Success state / 成功状态 |
| `copy` | `copy.svg` | Copy an image / 复制图片 |
| `trash-2` | `trash.svg` | Clear the queue / 清空队列 |

`trash-2` is a local compatibility name for the current upstream `trash` icon. Apart from that filename alias, the SVGs are exact upstream copies.

`trash-2` 是上游现有 `trash` 图标的本地兼容名称；除文件名外，所有 SVG 均与对应的上游文件完全一致。

## AppKit assets / AppKit 资源

The committed PDFs contain vector paths with a transparent 24 × 24-point page. They were generated from the adjacent SVGs using the already-installed `rsvg-convert` tool:

```sh
rsvg-convert --format pdf --width 24pt --height 24pt --output name.pdf name.svg
```

Load the PDF with `NSImage`, set `isTemplate = true`, and tint it in the interface. A 24-point page is intentional: the converter's default 96 DPI would otherwise turn a 24-pixel SVG into an 18-point PDF. Normal application builds use these committed PDFs and do not require a converter or a new runtime dependency.

已提交的 PDF 为透明背景、24 × 24 点的矢量页面。使用 `NSImage` 加载并设置 `isTemplate = true`，由界面统一着色。显式指定点单位可避免默认 96 DPI 将 24 像素 SVG 转为 18 点 PDF。常规构建直接使用这些 PDF，无需安装转换器或新增运行时依赖。

Keep this directory's `LICENSE` with the distributed icon PDFs. HoverCapture's own MIT license does not replace these third-party notices.

发布图标 PDF 时须同时保留本目录的 `LICENSE`；HoverCapture 自身的 MIT 许可证不能替代第三方声明。
