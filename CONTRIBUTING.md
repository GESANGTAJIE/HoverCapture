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

Remove private content from screenshots, logs, window titles, and file paths before posting. Do not include credentials. For security-sensitive reports, use GitHub's private reporting mechanism if enabled; do not publish exploit details or sensitive data in a public issue.

### Submit a change

1. Create a branch for one change and read the relevant source and existing tests.
2. Keep the implementation native and dependency-free unless a dependency is justified and agreed upon.
3. Add or update selection tests when changing hit testing or display fallback. Do not use a mock result as evidence that real macOS capture works.
4. Keep English and Chinese documentation and interface messages aligned.
5. Run `./scripts/test.sh`, then build with `./scripts/build.sh`.
6. Complete the relevant manual checks in [docs/TESTING.md](docs/TESTING.md).
7. Open a pull request explaining the problem, resulting behavior, checks run, and any checks you could not perform.

Do not commit generated apps, installation packages, screenshots of private desktops, credentials, signing certificates, notarization credentials, or local preference files. The repository's MIT License applies to contributed code.

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

发布前去掉截图、日志、窗口标题和文件路径中的私人内容，不要提供密钥或其他凭据。安全问题如果可以使用 GitHub 私密报告机制，请优先使用；不要把敏感数据或可直接利用的细节放在公开 Issue 里。

### 提交修改

1. 建立独立分支，先阅读相关实现和已有测试。
2. 优先使用原生系统功能，保持无第三方依赖；确需新增依赖时先说明理由并讨论。
3. 改动窗口命中、显示器选择时同步完善逻辑测试；不要把模拟测试当作真实截屏成功的证据。
4. 同步维护中英文说明与界面文字。
5. 运行 `./scripts/test.sh` 和 `./scripts/build.sh`。
6. 完成 [docs/TESTING.md](docs/TESTING.md) 中与改动相关的实机检查。
7. 在 Pull Request 中说明解决的问题、修改后的行为、实际验证结果及无法完成的检查。

不要提交生成的应用和安装包、包含私人桌面的截图、凭据、签名证书、公证凭据或本地偏好设置。贡献的代码遵循本仓库的 MIT 许可证。
