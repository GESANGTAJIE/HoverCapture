# Testing and release checks / 测试与发布检查

The status section records checks confirmed for the current preview. The remaining sections define how to test; **an item in the checklist is not a passing result**. Update the status as further checks are completed and record failures or checks not performed.

状态部分记录当前预览版已确认的检查，其余部分说明测试方法；**出现在清单中不代表已经通过**。后续完成检查时请更新状态，并明确失败与未执行项。

## 0.1.0 preview: current record / 预览版当前记录

Test host / 测试设备：**macOS 15.7.2, Apple Silicon**。

| Check / 检查 | Recorded result / 已记录结果 |
| --- | --- |
| Selection logic / 窗口选择逻辑 | **27 passed, 0 failed. / 27 项通过，0 项失败。** |
| Universal build / 通用架构构建 | `arm64` and `x86_64` compilation passed. / 两种架构均编译通过。 |
| Native application launch / 原生应用启动 | Launched on the Apple Silicon test Mac. / 已在 Apple Silicon 测试机实际启动。 |
| Settings layout / 设置界面布局 | Visually inspected on the test Mac. / 已在测试机做视觉检查。 |
| Shortcut recorder / 快捷键录入 | Changed from ⌃⌥⌘S to ⌃⌥⌘D and restored through the settings UI. Global capture triggering remains unverified. / 已在设置中改为 ⌃⌥⌘D 并恢复；全局触发截图仍待验证。 |
| Actual screenshot pixels and saved image / 真实截图及文件内容 | Awaiting acceptance testing. / 待实机验收。 |
| Clipboard image paste / 剪贴板图片粘贴 | Awaiting acceptance testing. / 待实机验收。 |
| Screen Recording authorization workflow / 屏幕录制授权流程 | Awaiting acceptance testing. / 待实机验收。 |
| Multiple displays and mixed scaling / 多显示器与混合缩放 | Awaiting acceptance testing. / 待实机验收。 |
| Intel Mac execution / Intel 实机运行 | Awaiting acceptance testing; cross-compilation does not verify execution. / 待实机验收，跨架构编译不等于实际运行验证。 |

The settings UI reported Screen Recording as allowed. The automated native-app input attempt did not produce a confirmed new screenshot, so neither image output nor clipboard delivery is marked as passed. Local disk-image creation returned `Device not configured` in the restricted environment; the ZIP-only package was generated instead.

设置界面显示屏幕录制已允许，但自动化按键尝试未生成可确认的新截图，因此不把图像输出或剪贴板交付记为通过。本地受限环境创建磁盘映像返回 `Device not configured`，已改用 ZIP 打包。

This is a **0.1.0 preview**, not a claim that all functions or all supported Macs have passed acceptance testing. The pending rows describe the current record and should be revised when new results are available. Other checklist items below have no passing result unless explicitly recorded.

当前定位为 **0.1.0 预览版**，不表示所有功能或所有支持机型已经完成验收。待验证项反映当前记录，得到新结果后应更新；下方其他清单项目，未明确记录通过的均不应视为已完成。

## Automated checks / 自动检查

Run from the repository root on a Mac with Apple's command-line build tools:

```sh
./scripts/test.sh
./scripts/build.sh
./scripts/package.sh
```

- The test script exercises pure target-selection logic. These tests do not grant Screen Recording permission and cannot validate captured pixels.
- The build script compiles and assembles a universal app for the minimum supported macOS version.
- The packaging script creates the DMG and ZIP for installation testing.
- Review command exit codes and complete output. Report a failed compilation or packaging step rather than continuing as if it succeeded.

自动测试主要验证目标选择逻辑，不申请录屏权限，也不能确认真实截图是否正确。构建验证编译与应用打包，安装包脚本验证 DMG/ZIP 生成。检查每一步退出状态和完整错误，不要忽略失败。

If the environment cannot create disk images, run `./scripts/package.sh --zip-only` to generate the universal ZIP and its checksum file. Record that no DMG was produced, skip the DMG verification command below, and verify the ZIP instead. This packaging mode does not change the app's signing or permission requirements.

如果环境无法创建磁盘映像，可运行 `./scripts/package.sh --zip-only`，生成通用 ZIP 与校验文件。请记录未生成 DMG，跳过下方 DMG 验证命令，改为验证 ZIP。这种打包方式不改变应用的签名状态或授权要求。

Additional startup and package checks:

```sh
build/HoverCapture.app/Contents/MacOS/HoverCapture --smoke-test
file build/HoverCapture.app/Contents/MacOS/HoverCapture
lipo -archs build/HoverCapture.app/Contents/MacOS/HoverCapture
codesign --verify --deep --strict --verbose=2 build/HoverCapture.app
hdiutil verify dist/HoverCapture-0.1.0-universal.dmg
unzip -t dist/HoverCapture-0.1.0-universal.zip
```

The smoke test checks application/menu/shortcut startup without taking a screenshot. Expect `arm64` and `x86_64` in a universal executable. A valid ad-hoc signature does **not** mean Gatekeeper will accept an internet-downloaded copy, and does **not** mean the app is notarized.

启动检查不截图，仅检查应用、菜单与快捷键启动过程。通用二进制应包含 `arm64` 和 `x86_64`。ad-hoc 签名校验成功，不代表网络下载后的应用会被 Gatekeeper 直接放行，也不代表已公证。

## Manual acceptance matrix / 实机验收清单

Test with harmless sample windows. Do not publish screenshots of private content as test artifacts.

请用不含私人内容的示例窗口测试，不要把私人桌面截图作为公开测试附件。

| Check / 检查 | Expected / 预期 |
| --- | --- |
| Fresh DMG install / 首次安装 | App drags into Applications, opens from there, and appears in the menu bar. / 拖到应用程序后可启动，菜单栏显示图标。 |
| Downloaded artifact / 网络下载包 | Record actual Gatekeeper behavior and confirm documented per-app opening steps work when available. / 记录真实拦截提示，确认单个应用的打开步骤。 |
| Permission denied / 拒绝录屏 | App explains the missing permission and provides a settings route; no silent success. / 显示授权提示与设置入口，不假报成功。 |
| Permission granted / 允许录屏 | After any required restart, capture works and status reflects authorization. / 必要重启后可截图，授权状态正确。 |
| Default shortcut / 默认快捷键 | One press captures without an extra click. / 按一次即可截图，无需再次点选。 |
| Custom shortcut / 自定义快捷键 | New combination works globally; old combination is released; setting survives restart. / 新组合全局生效，旧组合释放，重启后保留。 |
| Conflicting shortcut / 快捷键冲突 | Registration failure is visible; no false indication that the new shortcut works. / 注册失败可见，不假报已生效。 |
| Ordinary window / 普通窗口 | Correct PNG bounds; no neighboring windows, pointer, or shadow. / 边界正确，无其他窗口、鼠标或外部阴影。 |
| Occlusion / 遮挡 | Hover exposed area of lower window; verify its image excludes the covering window. / 指向下层窗口露出部分，图片不含遮挡窗口。 |
| Floating panel and modal dialog / 浮动面板与对话框 | Selection matches documented supported layers; document app-specific exceptions. / 符合支持范围，并记录特殊应用差异。 |
| Attached child and in-window popup / 子窗口与内部弹窗 | Separate child windows are not combined with parent; in-window pixels remain. / 不合并独立子窗口，保留窗口内部绘制内容。 |
| Desktop, Dock, and menu / 桌面、Dock、菜单 | Captures exactly the display under the pointer, with its visible contents. / 仅截鼠标所在显示器及其可见内容。 |
| Second monitor on each side / 副屏在四个方向 | Selection and fallback work with negative coordinates, vertical layouts, and pointer near boundaries. / 支持负坐标、上下排列及边界附近位置。 |
| Mixed display scaling / 混合缩放 | Verify sharpness, dimensions, and lack of cropping on Retina and non-Retina configurations. / 检查清晰度、尺寸及是否裁切错误。 |
| Window across displays / 窗口跨屏 | Correct window selected; inspect actual bounds and scale, noting system limitations. / 目标正确，检查实际范围、比例及系统限制。 |
| Current Space and full screen / 桌面空间与全屏 | Only currently hoverable windows are eligible; record full-screen behavior. / 仅选择当前可悬停窗口，记录全屏行为。 |
| Transparent window / 透明窗口 | Rectangular hit testing matches documented limitation; inspect alpha in saved PNG. / 符合矩形命中限制，检查 PNG 透明通道。 |
| Clipboard / 剪贴板 | Paste in an image-capable app and compare with the saved PNG. / 在支持图片的应用中粘贴，与文件一致。 |
| Default folder / 默认目录 | PNG appears in Downloads/WindowShots; absent directory is handled visibly. / 文件出现在默认目录，缺失目录有明确处理。 |
| Custom folder / 自选目录 | Test Documents, spaces, Chinese characters, and an external volume; choice survives restart. / 测试文稿、空格、中文、外接盘路径，重启后保留。 |
| Save failure / 保存失败 | Unwritable or disconnected destination produces clear failure; clipboard outcome is reported independently. / 不可写或断开的目录有明确提示，独立报告复制结果。 |
| Clipboard failure / 复制失败 | If reproducible or fault-injected, a saved file remains available and partial failure is clear. / 可复现或注入故障时，已保存文件仍可用，明确提示部分失败。 |
| Repeated shortcuts / 连续按键 | No overlapping corrupt captures, silent overwrites, or stuck busy state. / 无损坏截图、静默覆盖或永久忙碌状态。 |
| Closing target / 截图时关闭窗口 | Error has useful context and later captures still work. / 错误可理解，后续仍可正常截图。 |
| Login start / 登录启动 | Enable, approve if needed, sign out/in, confirm launch; disabling prevents it. / 启用并批准后重登可启动，关闭后不启动。 |
| Chinese and English / 中英文 | Readable settings, menus, alerts, and longer paths; no clipped labels. / 设置、菜单、提示和长路径可读，无裁切。 |
| Upgrade / 更新 | Quit/replace/reopen preserves preferences; record any renewed permission request. / 退出替换后保留设置，记录是否需重新授权。 |
| Quit and uninstall / 退出卸载 | Shortcut released on quit; login registration can be removed; screenshot files remain. / 退出释放快捷键，可取消登录启动，截图保留。 |

## Record results / 记录结果

For every release, include:

1. Commit or tag, package filename, build date, signing/notarization status.
2. macOS version/build, Mac architecture, display layout, and scaling.
3. Automated commands run and their pass/fail counts or exit results.
4. Manual checks actually completed, with any exceptions.
5. Untested configurations and unresolved problems.

每次发布应记录提交或版本标签、安装包、构建日期、签名与公证状态、系统及显示器环境、自动检查结果、实际完成的手工项，以及未测配置和未解决问题。不要把 ARM 上构建出 Intel 二进制写成 Intel 实机验证通过。
