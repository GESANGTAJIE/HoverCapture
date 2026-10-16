# Testing and release checks / 测试与发布检查

The status section records checks confirmed for the current preview. The remaining sections define how to test; **an item in the checklist is not a passing result**. Update the status as further checks are completed and record failures or checks not performed.

状态部分记录当前预览版已确认的检查，其余部分说明测试方法；**出现在清单中不代表已经通过**。后续完成检查时请更新状态，并明确失败与未执行项。

## 0.2.2 RC4: native mouse target / RC4：系统鼠标目标查询

RC3 failed acceptance on the affected **M1 / macOS Tahoe 26.1 (25B78)** Mac. Its build-7 report at `(783.45703125,91.2890625)` showed full-display Dock window 16 ahead of Finder window 6604, with `dockProbe id=16 alpha=visible detail=sampled`; the selected target was Screen. Replaying this metadata and visible probe result reproduced the failure. The separate Finder = Window / Dock = Screen confirmation came from **macOS 15.7.2**, not the affected Tahoe device.

RC4 (build 8) replaces the asynchronous Dock pixel probe with Apple's public [`NSWindow.windowNumber(at:belowWindowWithWindowNumber:)`](https://developer.apple.com/documentation/appkit/nswindow/windownumber(at:belowwindowwithwindownumber:)) query, always using `belowWindowWithWindowNumber: 0`. This queries the frontmost mouse recipient, including other apps, while excluding surfaces that are transparent at that location or ignore mouse events. The point is converted from Quartz to AppKit coordinates using the primary display, in logical points. The query, window list and selection are collected synchronously before the first capture suspension; subsequent pointer movement does not retarget the capture.

The returned positive window number must uniquely match a window in the same list with valid bounds, owner PID and alpha, containing the frozen pointer. Only a full-display, layer-20 Dock surface **ahead of that validated match** may be skipped. Selection then continues in the original order, so menus, HoverCapture's own window and unsupported overlays still block window capture. A Dock hit or missing, zero, unmatched or inconsistent evidence does not bypass Dock. No Dock image is captured for selection, and no additional Accessibility permission is requested.

Diagnostic version 3 records a `nativeHit` line with the returned window number, validated list index and converted AppKit point. It retains capture-time metadata, omits pixels, titles and paths, and is copied only on request; there is no automatic upload.

Local verification: **206 checks passed, 0 failed** (46 selection, 70 Tahoe/coordinate validation, 34 diagnostics, 18 language, 25 batch, 11 login, 2 packaging). Universal `arm64` / `x86_64` compilation and strict ad-hoc signature verification passed without compiler warnings. The restricted local environment explicitly skips native window-hit and pasteboard integration. Release CI requires the **20 native window-hit checks** on macOS 26 and macOS 15, plus **10 native pasteboard checks** on macOS 15; its result and package checks are recorded in the release notes. Synthetic hit IDs and successful compilation alone do not establish the affected device's native query result.

Native fixture investigation on 2026-10-16: the first macOS 15 CI attempt failed a global-alpha-zero expectation; aggregating results revealed an additional failure after changing an already displayed opaque window to nonopaque. After adding an AppKit event pump, own-view alpha checks and a fresh nonopaque fixture, Tahoe CI reported **18 passed, 2 failed**: the same two mutations still returned the front window. The fresh nonopaque window's solid and clear regions both behaved correctly. These are observed API/fixture limits, not proof of a stale WindowServer input mask. Global alpha and changing the opacity mode are now explicitly logged observations, excluded from passing-test counts. Fresh transparent-region assertions remain mandatory; the suite also requires correct hit changes when an already nonopaque window redraws its solid/clear regions. The app does not mutate other windows. A native query that still returns Dock keeps Screen fallback, so real Dock acceptance remains necessary.

**Affected-device acceptance is pending.** Install [RC4 (build 8)](https://github.com/GESANGTAJIE/HoverCapture/releases/tag/v0.2.2-rc.4) and keep Dock visible. Finder center must produce a target-only `Window-` image, and a visible Dock icon must produce `Screen-`; also repeat over empty desktop and a menu. Holding the pointer still after the shortcut is no longer required. On failure, copy the complete diagnosis and confirm version 3, `appVersion=0.2.2 build=8` and the `nativeHit` line. Homebrew remains at **0.2.1** until affected-device acceptance.

RC3 在受影响的 **M1／Tahoe 26.1（25B78）** 上未通过验收：鼠标位于 Finder 时，构建 7 的日志显示 `dockProbe id=16 alpha=visible detail=sampled`，最终仍选择全屏；回放该元数据与检测结果可复现失败。此前“Finder 为 Window、Dock 为 Screen”的结果仅来自 **macOS 15.7.2**，不能作为 Tahoe 验收结果。

RC4（构建 8）移除异步 Dock 像素检测，改用上述公开系统接口查询实际鼠标目标，查询参数始终为 `belowWindowWithWindowNumber: 0`。坐标按主显示器在 Quartz 与 AppKit 之间转换，不按 Retina 倍率缩放；在首次异步截图之前同步冻结查询、窗口列表和选择结果，按快捷键后无需保持鼠标不动。返回值必须在同一列表中唯一匹配有效窗口且包含鼠标位置；只有排在该匹配之前、全屏且层级 20 的 Dock 窗口允许跳过，其他阻挡规则保留。命中 Dock 或证据无效时仍回退全屏，不额外申请辅助功能权限，也不再生成用于检测的 Dock 图片。

诊断 v3 增加 `nativeHit` 行，包含窗口编号、匹配索引与转换后的坐标；仍不含图片、标题或路径，不自动上传。本地 **206 项通过、0 失败**，双架构构建及严格 ad-hoc 签名校验通过，无编译警告；受限环境明确跳过原生窗口与剪贴板集成。发布 CI 要求 macOS 26 与 15 各执行 **20 项原生窗口检查**，macOS 15 另执行 **10 项原生剪贴板检查**，结果与安装包检查记入发布说明。**受影响设备仍待验收，Homebrew 保持 0.2.1**；复测需确认 Finder 中央为仅含窗口的 `Window-`、Dock 图标为 `Screen-`，异常时提供构建 8 的完整 v3 诊断。

2026-10-16 的原生测试调查：初次 CI 在全局透明度设为零时失败，汇总检查又发现已有不透明窗口改为非不透明后，透明区域仍返回前面的窗口。补齐 AppKit 事件处理、验证视图绘制的透明通道并加入新建透明窗口后，Tahoe CI 为 **18 通过、2 失败**：两项变化仍返回前窗口，但新建非不透明窗口的实色／透明区域判断均正确。目前将这两项记录为独立观察，不计入通过数，不将原因断言为“旧命中区域缓存”。新建透明区域判断仍须通过，另要求非不透明窗口重绘实色／透明区域后正确更新命中。应用不会修改其他窗口；若系统查询仍返回 Dock，会保留全屏，因此实际 Dock 场景仍需验收。

## 0.2.2 RC3: superseded after failed Tahoe acceptance / RC3：Tahoe 验收失败，已被替代

The RC2 report from the affected M1 / Tahoe 26.1 (25B78) device identified the actual blocker: Dock window 16, layer 20, alpha 1, sharing 1, title present, bounds `(0,0,1440,900)`. At pointer `(691.4140625,242.34765625)`, it precedes Finder window 5206 at `(219,213,920,436)`. RC1 assumed sharing 0 and no title; the real trace disproves that signature. Replaying both the reported relevant-window order and the minimal Dock/Finder pair against RC2 failed: expected Finder, got screen.

RC3 (build 7) removes metadata-only skipping. Only a decisive full-display, layer-20 Dock surface is probed with a desktop-independent ScreenCaptureKit screenshot, explicit BGRA and `shouldBeOpaque = false`. A small clipped neighborhood at the frozen pointer must contain only zero-alpha pixels before selection may continue. Visible, unknown, unavailable or changed evidence retains Screen fallback. The temporary Dock image is not saved or copied. Window ID, owner PID, bounds, content dimensions and image dimensions must match; pointer changes detected before/after the async probe also retain Screen. Menus, Mission Control, ordinary windows and other overlays are not transparency-probed.

The report remains a text-only, manual-copy diagnostic. Version 2 adds `dockProbe` outcome/detail lines, retains capture-time metadata and never uploads automatically. Pointer checks compare with the frozen position; they do not retarget to a later position.

Local verification on 2026-10-15: **204 checks passed, 0 failed** (46 selection, 42 native CoreGraphics alpha sampling, 30 Tahoe resolver, 30 diagnostics, 18 language, 25 batch, 11 login, 2 packaging). Universal compilation and strict signature verification passed, with no compiler warnings in the final build. The restricted shell explicitly skipped native pasteboard integration. Tests combine the actual metadata fixture with controlled transparent/visible image samples; they do **not** establish that the affected Tahoe device supplies the expected alpha through ScreenCaptureKit.

Subsequent acceptance on 2026-10-15: Finder and Dock behaved as expected on macOS 15.7.2, but the affected Tahoe 26.1 Mac still selected Screen over Finder with `alpha=visible detail=sampled`. **RC3 failed affected-device acceptance and is superseded by RC4.** The checks above remain historical results for the RC3 implementation, not evidence that its pixel assumption held on Tahoe. Homebrew was not promoted.

RC2 真实报告确认了阻挡窗口：Dock、层级 20、全屏边界，但共享状态为 1 且有标题，推翻 RC1 的特征假设。旧选择器回放完整相关列表和精简 Dock/Finder 两窗口时均失败。RC3（构建 7）移除仅凭元数据跳过的规则，只有取得鼠标附近全透明像素证据才继续选择；可见、未知、读取失败或检测到鼠标变化时均保留全屏。检测图片只在内存使用，不保存、不复制，不增加辅助功能权限。

RC3 当时的本地 **204 项通过、0 失败**，双架构及严格签名检查通过，最终构建无编译警告；受限终端明确跳过原生剪贴板集成。后续 macOS 15.7.2 的 Finder／Dock 检查通过，但受影响的 Tahoe 26.1 在 Finder 上仍返回 `alpha=visible detail=sampled` 并截取全屏。**RC3 未通过受影响设备验收，已由 RC4 替代**，Homebrew 未升级。以上自动检查保留为历史记录，不代表像素检测假设在 Tahoe 上成立。

API references: Apple's [single-window filter](https://developer.apple.com/documentation/screencapturekit/sccontentfilter/init(desktopindependentwindow:)), [opacity control](https://developer.apple.com/documentation/screencapturekit/scstreamconfiguration/shouldbeopaque), and [sourceRect limitations](https://developer.apple.com/documentation/screencapturekit/scstreamconfiguration/sourcerect). Single-window capture ignores sourceRect, so sampling happens after obtaining the full Dock surface.

## 0.2.2 RC2 diagnostics / RC2 诊断

The affected M1/Tahoe 26.1 user tested RC1 and reported that hovering an ordinary window still captures the screen. The synthetic RC1 regression passing did not establish the actual device's window signature. **RC1 acceptance failed.** RC2 (build 6) leaves selection behavior unchanged and adds an explicit Copy Last Capture Diagnosis menu action.

The selector produces the actual target, reason, decisive window index and skipped Dock IDs in one operation. The report uses that result and the exact frozen inputs from the same capture, including relevant windows behind the blocker. Copying later does not re-read the pointer or window list. Unknown bundle IDs and sharing states stay unknown. The report contains no window titles, owner display names, paths or pixels; one report is retained in memory until the next attempt or app exit. No automatic file write or upload occurs. Copying is explicit and replaces clipboard contents; the screenshot batch is unchanged.

User workflow: install RC2, leave Dock visible, hover Finder, press the capture shortcut, choose Copy Last Capture Diagnosis, and send the text. Verify the text says `appVersion=0.2.2 build=6`. The menu is unavailable before a target snapshot; early failures clear a previous report. Homebrew remains on 0.2.1 pending diagnosis and a verified fix.

用户实测 RC1 后仍然全屏，**RC1 未通过受影响设备验收**。RC2（构建 6）保持选择行为不变，增加手动复制最近一次目标诊断。报告使用同次截图冻结的坐标、窗口列表和实际选择结果，不在点菜单时重新取样；保留未知字段的“未知”状态。报告仅在内存保留一份，不含窗口标题、进程显示名称、路径或图片，无自动写文件／上传。复制文字会替换剪贴板，不清空截图批次。

待用户提供 RC2 报告，首先核对 `appVersion=0.2.2 build=6`，再检查实际阻挡窗口及其元数据。Homebrew 保留 0.2.1。

Local verification: 128 checks passed (45 selection, 27 diagnostics, 18 language, 25 batch model, 11 login, 2 packaging); native pasteboard integration was explicitly skipped by the restricted shell. Diagnostic tests cover actual decision reasons/indexes, unknown metadata, windows behind a blocker, irrelevant-window omission, negative coordinates and non-finite diagnostic values. The original 45 selection expectations still pass. Menu availability and diagnostic copying on the affected Tahoe device remain pending. Copying is disabled while capture is in progress to prevent image delivery replacing the copied report.

本地 128 项通过（选择 45、诊断 27、语言 18、批次 25、登录项 11、打包 2）；受限终端跳过原生剪贴板集成。原有选择结果保持通过。截图进行中禁用诊断复制，避免截图随后覆盖刚复制的文字。受影响 Tahoe 设备上的菜单与报告复制尚待确认。

## 0.2.2 RC1: Tahoe Dock / RC1：Tahoe 程序坞

On 2026-10-14, a user reported that every capture over an ordinary Finder window on an M1 MacBook Pro running macOS Tahoe 26.1 produced a new `Screen-` PNG. No third-party overlay utilities were in use. With the existing app unchanged, enabling Dock autohide restored `Window-` captures. This isolates a Dock-related selection failure; the affected Mac's precise window metadata has not been collected.

The new regression failed before the selector fix: a Dock-owned, untitled, layer-20, sharing-state-0 window matching the entire display forced screen capture even when the pointer was over an ordinary app window. This is a synthetic fixture based on [a primary report of the signature on later Tahoe versions](https://github.com/anthropics/claude-code/issues/50719), not a metadata dump from the affected 26.1 Mac. The fix skips only that full signature and continues through the existing window order. Sharing state alone is not a visibility test.

Regression coverage includes multiple pointer positions, negative-origin displays, empty desktop, real Dock strips, menus, Mission Control's layer 18, non-Dock overlays, sharing/ title/ bounds mismatches, and a normal full-display window. Native metadata extraction uses bundle ID from PID and does not depend on localized owner names. Missing sharing-state data keeps the original conservative behavior.

Local verification on 2026-10-14: **101 checks passed, 0 failed** (45 selection, 18 language, 25 batch model, 11 login, 2 packaging). The restricted shell explicitly skipped native pasteboard integration. Universal arm64/x86_64 compilation, strict signature verification, and ZIP packaging passed. These do not establish the candidate's capture behavior on the affected Tahoe Mac.

**RC1 acceptance failed:** the user reported that an ordinary window still produces `Screen-` with Dock visible. The other proposed Dock/menu/Mission Control checks remain unverified. Do not promote the Homebrew cask based solely on unit-test results.

2026-10-14：用户确认 M1 MacBook Pro、Tahoe 26.1 上普通 Finder 窗口总生成 `Screen-`；没有使用第三方覆盖工具。保持旧应用不变，开启 Dock 自动隐藏后恢复 `Window-`，已定位到 Dock 相关判断，但未取得该机器的具体窗口元数据。新增模拟回归在修复前失败。修复仅跳过 Dock、层级 20、共享状态 0、空标题且边界等于单块显示器的组合，不把“共享状态 0”等同于不可见。

**RC1 实机验收失败：** 用户反馈 Dock 显示时普通窗口仍生成 `Screen-`。其他 Dock／菜单／Mission Control 验收未完成，不更新 Homebrew。

本地验证：**101 项通过，0 失败**（窗口选择 45、语言 18、批次 25、登录项 11、打包 2）。受限终端明确跳过原生剪贴板集成；双架构编译、严格签名检查和 ZIP 打包通过，不等同于 Tahoe 实机截图验收。

## 0.2.1 recovery and packaging / 异常恢复与打包

On 2026-10-13, the pending-login and stale-package regressions failed before their fixes. After the fixes, the local suite passed **83 checks**: the existing 70 model checks, 11 login-state/action/error checks, and 2 packaging regression checks. Native pasteboard integration remained explicitly skipped in the restricted local shell. Universal compilation, strict build-time signing verification, and ZIP packaging passed.

The capture callback is now a required, immutable HotKeyController constructor argument, so a failed first registration cannot skip its installation. Login settings use the tested action mapping and expose pending approval separately, with an explicit route to System Settings. Packaging always runs a fresh build and stops if that build fails even when an old app exists. The tests verify login state/action selection without modifying actual macOS login items. Live shortcut-conflict recovery and login approval/cancellation still need GUI acceptance; these tests are not substitutes for it.

2026-10-13：待批准登录项与旧构建打包的回归检查在修复前失败，修复后本地 **83 项通过**（原 70 项、登录项状态／操作／错误 11 项、打包回归 2 项）。受限终端仍明确跳过原生剪贴板集成；通用架构编译、构建时严格签名校验与 ZIP 打包通过。快捷键回调改为构造时必填、不可变，初次注册失败不会遗漏回调。登录项测试没有修改系统实际登录项；真实快捷键冲突恢复和登录项批准／取消仍待 GUI 验收。

The 0.2.0 release was freshly tested on the same date: a physical default shortcut produced one target-only 1172 × 952 PNG of the public test document, and Preview's New from Clipboard showed the matching image. This is evidence for 0.2.0, not a full capture acceptance result for the rebuilt 0.2.1.

同日已补测 0.2.0 发布版：实体快捷键产生一张 1172 × 952 的测试文稿窗口 PNG，Preview 从剪贴板新建显示同图。这是 0.2.0 的实测证据，不当作重建的 0.2.1 完整截图流程通过。

## 0.2.0 batch, language, and interface / 连续截图、语言与界面

Verified on 2026-10-12 on macOS 15.7.2, Apple Silicon:

- **70 model checks passed, 0 failed:** 27 selection, 18 language, and 25 batch checks. Batch checks include order, capacity limits and shrinking, retries after copy failure, latest-only mode, and preserving content copied by other apps.
- Both architectures built successfully. The English and Chinese settings windows were inspected, including the logo and Lucide vector icons. Language changes applied immediately. Capacity input and the stepper worked; entering 21 showed a localized error and retained the previous valid value.
- After quitting and relaunching, the selected Chinese language and capacity of 4 remained. The existing screenshot folder and global shortcut also remained unchanged. Test settings were restored to capacity 1 and Follow System afterward.
- A separate local GUI harness compiled the production `CaptureBatch.swift` and generated harmless numbered PNGs 01, 02, and 03. Both private and general native pasteboards contained three separate items in that order; `NSImage` and `NSURL` readers each returned three objects. Copy Latest returned only 03 and left the internal batch intact. Clearing emptied the batch without deleting the sample PNGs.
- **User-confirmed receiver checks:** the user pressed Command–V once into an empty draft in ChatGPT and, separately, WeChat. In both cases, all three images appeared in the correct order. No message was sent for these checks. Exact receiver versions were not recorded; this is a result for the tested setup, not all versions.
- The restricted shell could not reach the pasteboard service, even for a basic text write. Its native integration check was explicitly skipped; the GUI harness covered actual pasteboard access separately. CI runs `scripts/test.sh --require-pasteboard` to make native integration mandatory there.
- The rebuilt app reported that Screen Recording permission was needed. The complete physical-shortcut-to-capture workflow was not rerun on 0.2.0. The tests above validate batching and paste delivery using generated PNGs, not new screen-capture acceptance. The earlier capture baseline is recorded below.

2026-10-12 在 macOS 15.7.2、Apple Silicon 上完成：**70 项逻辑检查通过，0 失败**
（窗口选择 27、语言 18、批次 25），两种架构均编译成功。中英文界面、Logo 与 Lucide 图标已检查；
手动语言立即生效，数量输入及加减按钮可用，输入 21 会显示中文错误并保留原值。
重启后中文选择与数量 4 均保留，原目录和快捷键不变；测试后恢复数量 1 和跟随系统。

单独的本机 GUI 测试工具直接复用生产版 `CaptureBatch.swift`，生成无隐私编号图 01、02、03。
私有及系统剪贴板均读回三项，PNG、文件与图片读取顺序一致；仅复制最新一张时得到 03；清空不删除 PNG。
用户分别在 ChatGPT 和微信空白草稿中按一次 ⌘V，均确认三张图全部出现、顺序正确，测试未发送消息。
未记录接收应用的具体版本，因此不将结果推广至所有版本。

受限终端连基础文本剪贴板写入也不可用，已明确跳过该环境的原生集成检查，并以上述 GUI 实测补充；
云端测试要求原生剪贴板检查必须通过。重建版本仍需屏幕录制授权，本次没有重跑实体快捷键到截图的完整链路，
批次和粘贴验收使用的是生成的 PNG。此前真实截图的验收基线保留如下。

## 0.1.1 branding update / 品牌更新

Verified on 2026-10-12 on macOS 15.7.2, Apple Silicon:

- Selection tests: **27 passed, 0 failed**. Universal compilation and build-time ad-hoc signature verification passed.
- Both SVG originals and the README banner match the supplied files byte for byte. The generated ICNS and bundled vector menu icon decoded successfully in AppKit; light/dark asset previews and small icon sizes were visually inspected. A live system appearance switch was not tested.
- The updated app launched through the desktop UI. The shortcut remained **⌃⌥⌘S** and the folder remained **`~/Downloads/WindowShots`**.
- The rebuilt ad-hoc app reported **Permission needed**. Screen Recording was not re-granted and physical capture/clipboard tests were not repeated for this branding update. The 0.1.0 results below remain the earlier functional baseline.
- Local ZIP packaging and ZIP integrity checks passed. The direct shell `--smoke-test` attempt aborted during AppKit application registration in the restricted session; the successful desktop launch is recorded separately, not as a passing CLI smoke test.

2026-10-12 在 macOS 15.7.2、Apple Silicon 上验证：27 项选择逻辑测试通过、0 项失败；
两种架构编译和构建时 ad-hoc 签名验证通过。原始 SVG 和横幅与用户提供文件逐字节一致，
AppKit 可读取生成的 ICNS 和包内菜单栏矢量图，已检查深浅背景下的资源预览及小尺寸显示，
未实际切换系统外观。新版通过桌面界面启动成功，快捷键和保存目录均保留。
重建后的应用显示需要屏幕录制权限，本次未重新授权、未重测实体快捷键截图与剪贴板；
下方 0.1.0 结果作为历史功能基线。新版本地 ZIP 打包及完整性检查通过。
受限终端内的 `--smoke-test` 在 AppKit 注册应用阶段中止，不将桌面启动成功记作 CLI 检查通过。

## 0.1.0 preview: earlier functional record / 此前的功能验证记录

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

This is the **0.1.0 preview baseline**, not a claim that all functions or all supported Macs have passed acceptance testing. The pending rows should be revised when new results are available. Other checklist items below have no passing result unless explicitly recorded.

以上是 **0.1.0 预览版功能基线**，不表示所有功能或所有支持机型已经完成验收。待验证项得到新结果后应更新；下方其他清单项目，未明确记录通过的均不应视为已完成。

## Automated checks / 自动检查

Run from the repository root on a Mac with Apple's command-line build tools:

```sh
./scripts/test.sh
./scripts/build.sh
./scripts/package.sh
```

- The test script exercises selection, coordinate conversion, diagnostics, language, batching, login settings and packaging. Native integration checks exercise the window-hit API with test-owned windows and the pasteboard. No test grants Screen Recording permission or validates real screenshot pixels.
- In restricted environments, unavailable native GUI/pasteboard checks are explicitly skipped. Release CI runs `./scripts/test.sh --require-window-hit --require-pasteboard` so those checks are mandatory; a functional test failure is not a skip.
- The build script compiles and assembles a universal app for the minimum supported macOS version.
- The packaging script creates the DMG and ZIP for installation testing.
- Review command exit codes and complete output. Report a failed compilation or packaging step rather than continuing as if it succeeded.

自动测试验证选择、坐标转换、诊断、语言、批次、登录设置与打包；原生集成检查使用测试工具自建窗口验证命中接口，并验证剪贴板。测试不申请录屏权限，也不能确认真实截图是否正确。受限环境中不可用的原生检查会明确跳过；发布 CI 使用 `--require-window-hit --require-pasteboard` 要求两组执行，功能测试失败不能记为跳过。构建验证编译与应用打包，安装包脚本验证 DMG/ZIP 生成。检查每一步退出状态和完整错误，不要忽略失败。

If the environment cannot create disk images, run `./scripts/package.sh --zip-only` to generate the universal ZIP and its checksum file. Record that no DMG was produced, skip the DMG verification command below, and verify the ZIP instead. This packaging mode does not change the app's signing or permission requirements.

如果环境无法创建磁盘映像，可运行 `./scripts/package.sh --zip-only`，生成通用 ZIP 与校验文件。请记录未生成 DMG，跳过下方 DMG 验证命令，改为验证 ZIP。这种打包方式不改变应用的签名状态或授权要求。

Additional startup and package checks:

```sh
build/HoverCapture.app/Contents/MacOS/HoverCapture --smoke-test
file build/HoverCapture.app/Contents/MacOS/HoverCapture
lipo -archs build/HoverCapture.app/Contents/MacOS/HoverCapture
codesign --verify --deep --strict --verbose=2 build/HoverCapture.app
hdiutil verify dist/HoverCapture-0.2.0-universal.dmg
unzip -t dist/HoverCapture-0.2.0-universal.zip
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
