# Contributing / 参与贡献

## English

Thank you for helping improve HoverCapture. Keep changes focused on its core workflow: hover, press one shortcut, save and copy the correct image.

### Report a bug

Use a GitHub Issue and include:

- HoverCapture version and how you installed or built it.
- macOS version and Apple Silicon / Intel architecture.
- Target app and whether the target is an ordinary window, dialog, menu, or full-screen app.
- Monitor arrangement, scaling, and which display contains the pointer.
- Steps to reproduce, expected behavior, actual behavior, and exact error text.
- Screen Recording permission state and whether restarting the app changes the result.
- For paste issues: batch capacity, image count, receiving app/version, and whether it accepts images, files, or only the first item. For language issues: selected interface language and primary macOS language.

Remove private content from screenshots, logs, window titles, and file paths before posting. Do not include credentials. For security-sensitive reports, use GitHub's private reporting mechanism if enabled; do not publish exploit details or sensitive data in a public issue.

### Submit a change

1. Create a branch for one change and read the relevant source and existing tests.
2. Keep the implementation native and dependency-free unless a dependency is justified and agreed upon.
3. Update the relevant selection, batch, or language tests. For batch changes, cover ordering, capacity limits, clearing, and preserving clipboard content copied in another app. Do not use a mock result as evidence that real macOS capture or a receiving app's multi-image paste works.
4. Keep English and Chinese documentation and interface messages aligned. Check both language choices and Follow System; use the existing logo, brand colors, and bundled Lucide icon set for interface changes.
5. Run `./scripts/test.sh`, then build with `./scripts/build.sh`.
6. Complete the relevant manual checks in [docs/TESTING.md](docs/TESTING.md).
7. Open a pull request explaining the problem, resulting behavior, checks run, and any checks you could not perform.

Do not commit generated apps, installation packages, screenshots of private desktops, credentials, signing certificates, notarization credentials, or local preference files. The repository's MIT License applies to contributed code.

Keep Lucide's complete [third-party license](https://github.com/GESANGTAJIE/HoverCapture/blob/main/Resources/Icons/LICENSE) with distributed icons. The README credits ChesterGe for product, design, and maintenance, and GPT (OpenAI) as the AI co-author for implementation and documentation. This credit does not change the MIT copyright notice or imply a GitHub account for GPT.

## 简体中文

请围绕核心操作改进：鼠标悬停，按一次快捷键，保存并复制正确的图片。一次提交尽量只解决一个问题。

### 报告问题

请在 GitHub Issue 中包含：

- HoverCapture 版本，以及安装包来源或构建方式。
- macOS 版本，Apple Silicon 或 Intel 架构。
- 目标应用，以及目标是普通窗口、对话框、菜单还是全屏应用。
- 显示器排列、缩放设置、鼠标所在显示器。
- 复现步骤、预期行为、实际行为、完整错误文字。
- 屏幕录制授权情况，退出重启后是否有变化。
- 粘贴问题请补充连续截图容量、图片数量、接收应用及版本，以及它接收的是图片、文件还是仅第一项；语言问题请补充所选界面语言和 macOS 首选语言。

发布前去掉截图、日志、窗口标题和文件路径中的私人内容，不要提供密钥或其他凭据。安全问题如果可以使用 GitHub 私密报告机制，请优先使用；不要把敏感数据或可直接利用的细节放在公开 Issue 里。

### 提交修改

1. 建立独立分支，先阅读相关实现和已有测试。
2. 优先使用原生系统功能，保持无第三方依赖；确需新增依赖时先说明理由并讨论。
3. 同步完善相关窗口选择、截图组或语言测试。截图组改动需覆盖顺序、容量边界、清空，以及保留其他应用新复制的内容；不要把模拟测试当作真实截屏或接收应用多图粘贴成功的证据。
4. 同步维护中英文说明与界面文字，检查两种手动语言及跟随系统选项；界面改动沿用现有 Logo、品牌色和内置 Lucide 图标。
5. 运行 `./scripts/test.sh` 和 `./scripts/build.sh`。
6. 完成 [docs/TESTING.md](docs/TESTING.md) 中与改动相关的实机检查。
7. 在 Pull Request 中说明解决的问题、修改后的行为、实际验证结果及无法完成的检查。

不要提交生成的应用和安装包、包含私人桌面的截图、凭据、签名证书、公证凭据或本地偏好设置。贡献的代码遵循本仓库的 MIT 许可证。

分发图标时须保留 Lucide 的完整[第三方许可证](https://github.com/GESANGTAJIE/HoverCapture/blob/main/Resources/Icons/LICENSE)。README 共同作者栏注明 ChesterGe 负责产品、设计与维护，GPT（OpenAI）作为 AI 共同作者参与实现与文档；这一署名不改变 MIT 版权声明，也不表示 GPT 拥有对应的 GitHub 账号。
