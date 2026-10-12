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
| Default global shortcut / 默认全局快捷键 | Passed on 2026-10-12: one physical press of ⌃⌥⌘S produced one new screenshot. / 2026-10-12 通过：实体键盘按一次 ⌃⌥⌘S，新增一张截图。 |
| Ordinary window image / 普通窗口截图 | Passed: a 1172 × 952 PNG contained only the public test document window, without surrounding desktop, other windows, or external shadow. / 通过：1172 × 952 PNG 仅含公开测试文稿窗口，无周围桌面、其他窗口或外部阴影。 |
| Default save folder / 默认目录保存 | Passed: the new Window PNG appeared in `~/Downloads/WindowShots`. / 通过：默认目录新增 Window PNG。 |
| Clipboard image / 剪贴板图片 | Passed: Preview's New from Clipboard (⌘N) displayed the same screenshot. / 通过：预览中用 ⌘N 从剪贴板新建，显示同一张截图。 |
| Settings persistence / 设置持久化 | Passed: ⌃⌥⌘D and a selected folder containing Chinese characters and spaces survived an app restart; permission remained Allowed. / 通过：改为 ⌃⌥⌘D 和含中文、空格的目录后重启，两项设置保留，权限仍为已允许。 |
| Customized shortcut capture / 自定义快捷键实际截图 | Passed: a physical ⌃⌥⌘D press produced one new Screen PNG. / 通过：实体键盘按下 ⌃⌥⌘D 后新增一张 Screen PNG。 |
| Custom save folder / 自选目录保存 | Passed: the Screen PNG was written into the selected folder containing Chinese characters and spaces. / 通过：Screen PNG 成功写入含中文与空格的自选目录。 |
| Single-display desktop fallback / 单显示器桌面回退 | Passed: pointing at empty desktop produced a 2880 × 1800 image containing the desktop, menu bar, and visible windows. / 通过：指向桌面空白处后生成 2880 × 1800 图片，包含桌面、菜单栏和可见窗口。 |
| Screen Recording permission recovery / 屏幕录制权限恢复 | Verified on 2026-10-12: remove the old HoverCapture entry, add the current app, then Quit & Reopen; the app reports Allowed. / 2026-10-12 已实测：移除旧条目，添加当前应用，退出重开后显示已允许。 |
| Release packages / 发布安装包 | GitHub CI generated DMG and ZIP on 2026-10-11. Both local checksum checks, ZIP integrity, and DMG verification passed. / GitHub CI 于 2026-10-11 生成 DMG 与 ZIP；两个文件的本地校验和、ZIP 完整性和 DMG 验证均通过。 |
| Release ZIP app signature / 发行 ZIP 内应用签名 | Passed after extraction into a clean temporary directory: `codesign --verify --deep --strict`; executable contains `arm64` and `x86_64`. / 干净临时目录解包后，上述签名校验通过，二进制包含两种架构。 |
| First-install authorization / 首次安装授权 | Awaiting acceptance testing; recovery of an existing entry does not cover first installation. / 待实机验收，已有授权条目的恢复不等于首次安装流程通过。 |
| Occluded windows / 遮挡窗口 | Awaiting acceptance testing. / 待实机验收。 |
| Dialogs, sheets, and popups / 对话框、附属表单与弹窗 | Awaiting acceptance testing. / 待实机验收。 |
| Dock and menu fallback / Dock 与菜单回退 | Awaiting acceptance testing; the verified fallback target was empty desktop. / 待实机验收，已验证的回退目标为桌面空白处。 |
| Multiple displays and mixed scaling / 多显示器与混合缩放 | Awaiting acceptance testing. / 待实机验收。 |
| Intel Mac execution / Intel 实机运行 | Awaiting acceptance testing; cross-compilation does not verify execution. / 待实机验收，跨架构编译不等于实际运行验证。 |
| Launch at login / 登录启动 | Awaiting acceptance testing. / 待实机验收。 |

An earlier automated native-app input attempt did not produce a confirmed screenshot. The later physical keyboard check documented below verified the default capture workflow. The unsuccessful automated attempt does not establish an app defect or the cause of that attempt's failure.

较早的自动化发键未生成可确认的截图，之后的实体键盘检查已验证默认截图流程，详见下文。此前自动化尝试未成功，不能据此确定应用存在缺陷或断定该次失败原因。

### 2026-10-11 packages / 安装包验证

GitHub CI produced both the universal DMG and ZIP. The downloaded files' local SHA-256 checksum checks passed, as did ZIP integrity testing and DMG verification. An earlier local DMG attempt returned `Device not configured` in the restricted environment and used ZIP-only packaging as a fallback. That local environment limitation did not prevent CI from producing the DMG.

GitHub CI 已生成通用 DMG 与 ZIP。下载后，两个文件的本地 SHA-256 校验和均匹配，ZIP 完整性检查与 DMG 验证均通过。更早一次本地 DMG 创建返回 `Device not configured`，当时在受限环境中用 ZIP 打包作为后备方案；该本地环境限制没有阻止 CI 生成 DMG。

### 2026-10-12 follow-up / 后续验收记录

On the same macOS 15.7.2 Apple Silicon host, System Settings showed an enabled HoverCapture screen-access toggle associated with the older ad-hoc build, while the current build showed **Permission needed**. In the system UI, removing only HoverCapture's old entry, adding the exact current `.app`, and choosing **Quit & Reopen** restored the app's **Allowed** status. This confirms permission-state recovery for this case.

在同一台 macOS 15.7.2 Apple Silicon 测试机上，系统设置中旧 ad-hoc 构建对应的 HoverCapture 屏幕访问开关已开启，当前构建却显示 **Permission needed（需要授权）**。通过系统界面仅移除 HoverCapture 旧条目、添加准确的当前 `.app`，再选择 **Quit & Reopen（退出并重新打开）**，应用恢复显示 **Allowed（已允许）**。本次确认的是该情形下的权限状态恢复。

The user then pressed **⌃⌥⌘S once on a physical keyboard**. Exactly one new `Window` PNG appeared in `~/Downloads/WindowShots`, measuring **1172 × 952 pixels**. Visual inspection showed the public test document **HoverCapture-test.rtf** window, with no surrounding desktop, other windows, or external shadow. In Preview, **⌘N (New from Clipboard)** displayed the same image. This confirms the default global shortcut, ordinary-window capture, default-folder saving, and image clipboard delivery for this test.

随后用户在**实体键盘按了一次 ⌃⌥⌘S**。`~/Downloads/WindowShots` 恰好新增一张 **1172 × 952 像素**的 `Window` PNG。视觉检查确认内容为公开测试文稿 **HoverCapture-test.rtf** 的窗口，无周围桌面、其他窗口或外部阴影。在“预览”中按 **⌘N（从剪贴板新建）**，显示同一张图片。本次确认默认全局快捷键、普通窗口截图、默认目录保存和图片剪贴板交付通过。

The shortcut was then changed in the UI to **⌃⌥⌘D**, and a folder containing Chinese characters and spaces was selected. After restarting the app, both settings persisted and Screen Recording still showed **Allowed**. With the pointer on empty desktop, the user physically pressed **⌃⌥⌘D**. Exactly one new **2880 × 1800** `Screen` PNG appeared in the chosen folder. Visual inspection confirmed the desktop, menu bar, and visible windows. This verifies custom shortcut activation, custom-folder writing, and the empty-desktop fallback on the single-display test setup; it does not cover multiple displays or Dock/menu hit testing.

之后通过界面把快捷键改为 **⌃⌥⌘D**，选择含中文与空格的文件夹。重启后两项设置均保留，屏幕录制仍显示 **Allowed（已允许）**，设置持久化通过。用户把鼠标放在桌面空白处，实体键盘按下 **⌃⌥⌘D**，自选目录恰好新增一张 **2880 × 1800** 的 `Screen` PNG。看图确认包含桌面、菜单栏和可见窗口。因此，自定义快捷键触发、自选目录写入和单显示器桌面回退通过；这不覆盖多显示器或 Dock／菜单命中。

After testing, the settings UI confirmed that the shortcut was restored to **⌃⌥⌘S**, the folder to **`~/Downloads/WindowShots`**, and Screen Recording remained **Allowed**.

测试结束后，已在设置界面确认快捷键恢复为 **⌃⌥⌘S**，目录恢复为 **`~/Downloads/WindowShots`**，屏幕录制仍为 **Allowed（已允许）**。

The published ZIP was also extracted into a clean temporary directory. `codesign --verify --deep --strict` passed for the extracted app, and its executable contained both `arm64` and `x86_64`. This validates the archive's ad-hoc signature and architecture contents, not Developer ID signing, notarization, or Intel execution.

发行 ZIP 也已在干净临时目录解包，应用的 `codesign --verify --deep --strict` 校验通过，二进制包含 `arm64` 与 `x86_64`。这验证的是归档内应用的 ad-hoc 签名与架构内容，不等于 Developer ID 签名、公证或 Intel 实机运行通过。

Permission-recovery steps are in [the English README](../README.md#system-permission-is-on-but-the-app-says-permission-needed) and [中文说明](../README.zh-CN.md#常见问题). No other app's permissions or system protections need to be changed.

权限恢复步骤见上述 README 链接，不需要改动其他应用的权限或关闭系统保护。

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
