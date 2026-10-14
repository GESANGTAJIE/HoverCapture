import AppKit
import CoreGraphics
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSTextFieldDelegate {
    private let defaults = UserDefaults.standard
    private let engine = CaptureEngine()
    private var hotKeys: HotKeyController?
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var folderLabel: NSTextField?
    private var permissionLabel: NSTextField?
    private var shortcutButton: ShortcutButton?
    private var loginButton: NSButton?
    private var loginApprovalButton: NSButton?
    private var capacityField: NSTextField?
    private var capacityStepper: NSStepper?
    private var batchLabel: NSTextField?
    private var batchButtons: [NSButton] = []
    private var isCapturing = false
    private var feedbackTask: Task<Void, Never>?

    private var outputDirectory: URL {
        let path = defaults.string(forKey: "outputDirectory")
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads/WindowShots").path
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    private var savedShortcut: CaptureShortcut {
        guard let data = defaults.data(forKey: "shortcut"),
              let shortcut = try? JSONDecoder().decode(CaptureShortcut.self, from: data) else { return .standard }
        return shortcut
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let capacity = defaults.object(forKey: "batchCapacity") as? Int ?? 1
        _ = engine.batch.setCapacity(capacity)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        restoreStatusIcon()
        statusItem.menu = NSMenu()
        statusItem.menu?.delegate = self
        do {
            hotKeys = try HotKeyController(onPress: { [weak self] in
                guard let self else { return }
                if self.shortcutButton?.isRecording == true {
                    self.shortcutButton?.cancelRecording()
                } else {
                    self.takeScreenshot()
                }
            })
            try hotKeys?.register(savedShortcut)
        } catch {
            NSLog("HoverCapture: hotkey setup failed: %@", error.localizedDescription)
            if CommandLine.arguments.contains("--smoke-test") { exit(1) }
            showError(error.localizedDescription)
        }
        if CommandLine.arguments.contains("--smoke-test") {
            print("SMOKE PASS: menu bar created; global shortcut registered; bundle \(Bundle.main.bundleIdentifier ?? "unknown")")
            NSApp.terminate(nil)
            return
        }
        if !defaults.bool(forKey: "hasLaunched") || !CGPreflightScreenCaptureAccess() {
            showSettings()
            defaults.set(true, forKey: "hasLaunched")
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) { refreshSettings() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }
    func applicationWillTerminate(_ notification: Notification) { feedbackTask?.cancel() }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let title = NSMenuItem(title: "HoverCapture", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        let hint = NSMenuItem(title: AppText.pick("截图快捷键：", "Capture: ") + (hotKeys?.shortcut?.label ?? "—"), action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)
        menu.addItem(.separator())
        addItem(menu, AppText.pick("设置…", "Settings…"), #selector(showSettings))
        if engine.batch.count > 0 {
            addItem(menu, AppText.pick("复制整组（\(engine.batch.count) 张）", "Copy batch (\(engine.batch.count) images)"), #selector(copyBatch))
            addItem(menu, AppText.pick("仅复制最新一张", "Copy latest image only"), #selector(copyLatest))
            addItem(menu, AppText.pick("清空待粘贴截图", "Clear capture batch"), #selector(clearBatch))
        }
        addItem(menu, AppText.pick("打开截图文件夹", "Open Screenshots Folder"), #selector(openFolder))
        addItem(menu, AppText.pick("屏幕录制权限…", "Screen Recording Permission…"), #selector(openPrivacy))
        let diagnostic = NSMenuItem(title: AppText.pick("复制上次截图诊断", "Copy Last Capture Diagnosis"),
                                    action: engine.lastDiagnostic == nil || isCapturing ? nil : #selector(copyDiagnostic),
                                    keyEquivalent: "")
        diagnostic.target = self
        menu.addItem(diagnostic)
        menu.addItem(.separator())
        addItem(menu, AppText.pick("关于 HoverCapture", "About HoverCapture"), #selector(showAbout))
        addItem(menu, AppText.pick("退出 HoverCapture", "Quit HoverCapture"), #selector(quit), key: "q")
    }

    private func addItem(_ menu: NSMenu, _ title: String, _ action: Selector, key: String = "") {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
    }

    private func takeScreenshot() {
        guard !isCapturing else { return }
        engine.clearDiagnostic()
        guard CGPreflightScreenCaptureAccess() else {
            showSettings()
            showError(AppText.pick("请先开启 HoverCapture 的屏幕录制权限。授权后如仍不可用，请退出并重新打开应用。",
                "Enable Screen Recording for HoverCapture first. If access remains unavailable, quit and reopen the app after granting permission."))
            return
        }
        isCapturing = true
        feedbackTask?.cancel()
        restoreStatusIcon()
        Task {
            defer {
                isCapturing = false
                refreshSettings()
            }
            do {
                let result = try await engine.capture(directory: outputDirectory)
                if let warning = result.warning {
                    showError(warning)
                } else {
                    statusItem.button?.image = AppTheme.icon("check")
                    statusItem.button?.setAccessibilityLabel(AppText.pick("截图已保存并复制", "Screenshot saved and copied"))
                    statusItem.button?.toolTip = AppText.pick("已保存并复制到剪贴板", "Saved and copied to clipboard")
                    feedbackTask = Task { [weak self] in
                        do { try await Task.sleep(nanoseconds: 2_000_000_000) }
                        catch { return }
                        self?.restoreStatusIcon()
                    }
                }
            } catch {
                NSLog("HoverCapture: screenshot failed: %@", error.localizedDescription)
                showError(error.localizedDescription)
            }
        }
    }

    private func restoreStatusIcon() {
        if let image = NSImage(named: "StatusBarIconTemplate") {
            image.size = NSSize(width: 18 * image.size.width / image.size.height, height: 18)
            statusItem.button?.image = image
        } else {
            NSLog("HoverCapture: bundled StatusBarIconTemplate image is missing")
            statusItem.button?.image = NSImage(systemSymbolName: "viewfinder", accessibilityDescription: "HoverCapture")
        }
        statusItem.button?.image?.isTemplate = true
        statusItem.button?.setAccessibilityLabel("HoverCapture")
        statusItem.button?.toolTip = "HoverCapture — " + savedShortcut.label
    }

    @objc private func showSettings() {
        if settingsWindow == nil { buildSettings() }
        refreshSettings()
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func buildSettings() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 660),
            styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = AppTheme.black
        window.appearance = NSAppearance(named: .aqua)
        window.center()
        settingsWindow = window
        populateSettings(window)
    }

    private func populateSettings(_ window: NSWindow) {
        window.title = AppText.pick("HoverCapture 设置", "HoverCapture Settings")
        let content = AppTheme.surface(AppTheme.white)
        window.contentView = content
        let header = AppTheme.surface(AppTheme.black)
        header.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(header)
        let logo = NSImageView()
        logo.image = NSImage(named: NSImage.Name("NSApplicationIcon"))
        logo.imageScaling = .scaleProportionallyUpOrDown
        logo.setAccessibilityLabel("HoverCapture")
        logo.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(logo)
        let title = AppTheme.label("HoverCapture", size: 30, weight: .bold, color: AppTheme.white)
        let tagline = AppTheme.label(AppText.pick("指向窗口，按下快捷键，即可粘贴。", "Hover over a window. Press your shortcut. Paste."),
            size: 13, color: AppTheme.white.withAlphaComponent(0.72))
        let titles = NSStackView(views: [title, tagline])
        titles.orientation = .vertical
        titles.alignment = .leading
        titles.spacing = 8
        titles.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(titles)
        let accent = AppTheme.surface(AppTheme.orange)
        accent.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(accent)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: content.topAnchor),
            header.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 116),
            logo.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 22),
            logo.centerYAnchor.constraint(equalTo: header.centerYAnchor, constant: -3),
            logo.widthAnchor.constraint(equalToConstant: 90), logo.heightAnchor.constraint(equalToConstant: 90),
            titles.leadingAnchor.constraint(equalTo: logo.trailingAnchor, constant: 14),
            titles.centerYAnchor.constraint(equalTo: logo.centerYAnchor),
            accent.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            accent.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            accent.bottomAnchor.constraint(equalTo: header.bottomAnchor), accent.heightAnchor.constraint(equalToConstant: 3)
        ])
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 30),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -30),
            stack.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 18)
        ])

        let permission = AppTheme.label("", weight: .medium)
        permissionLabel = permission
        stack.addArrangedSubview(row(icon: "shield-check", title: AppText.pick("屏幕录制权限", "Screen Recording"),
            subtitle: AppText.pick("允许后即可开始截图", "Allow access to start capturing"),
            controls: [permission, button(AppText.pick("打开设置", "Open Settings"), #selector(openPrivacy))]))
        stack.addArrangedSubview(divider())

        let path = AppTheme.label("", size: 12, color: AppTheme.secondary)
        path.lineBreakMode = .byTruncatingMiddle
        path.widthAnchor.constraint(equalToConstant: 445).isActive = true
        folderLabel = path

        let recorder = ShortcutButton(title: savedShortcut.label, target: nil, action: nil)
        recorder.target = recorder
        recorder.action = #selector(ShortcutButton.beginRecording(_:))
        recorder.bezelStyle = .rounded
        recorder.controlSize = .large
        recorder.contentTintColor = AppTheme.black
        recorder.shortcut = savedShortcut
        recorder.toolTip = AppText.pick("点击后按新的组合键；至少包含 Control、Option 或 Command。", "Click, then press a combination with Control, Option, or Command.")
        recorder.onChange = { [weak self] proposed in
            guard let self else { return }
            do {
                guard let hotKeys = self.hotKeys else { throw HotKeyError(status: -1) }
                try hotKeys.register(proposed)
                self.defaults.set(try JSONEncoder().encode(proposed), forKey: "shortcut")
                self.shortcutButton?.shortcut = proposed
                self.restoreStatusIcon()
            } catch { self.showError(error.localizedDescription) }
        }
        shortcutButton = recorder
        stack.addArrangedSubview(row(icon: "keyboard", title: AppText.pick("截图快捷键", "Capture shortcut"),
            subtitle: AppText.pick("点击右侧修改，按 Esc 取消", "Click to change; press Esc to cancel"), controls: [recorder]))
        stack.addArrangedSubview(row(icon: "folder-open", title: AppText.pick("保存位置", "Save location"),
            subtitleView: path, controls: [button(AppText.pick("选择文件夹…", "Choose Folder…"), #selector(chooseFolder))]))
        stack.addArrangedSubview(divider())

        let capacity = NSTextField(string: String(engine.batch.capacity))
        capacity.alignment = .center
        capacity.font = .monospacedDigitSystemFont(ofSize: 15, weight: .medium)
        capacity.delegate = self
        capacity.target = self
        capacity.action = #selector(changeCapacity(_:))
        capacity.setAccessibilityLabel(AppText.pick("连续截图数量，1 到 20", "Batch capacity, 1 to 20"))
        capacity.widthAnchor.constraint(equalToConstant: 48).isActive = true
        capacityField = capacity
        let stepper = NSStepper()
        stepper.minValue = 1
        stepper.maxValue = 20
        stepper.integerValue = engine.batch.capacity
        stepper.target = self
        stepper.action = #selector(changeCapacity(_:))
        stepper.setAccessibilityLabel(AppText.pick("调整连续截图数量", "Adjust batch capacity"))
        capacityStepper = stepper
        stack.addArrangedSubview(row(icon: "layers", title: AppText.pick("连续截图", "Capture batch"),
            subtitle: AppText.pick("保留最近几张，一次粘贴 · 1–20 张", "Keep the latest images for one paste · 1–20"), controls: [capacity, stepper]))

        let batch = AppTheme.label("", size: 12, weight: .medium, color: AppTheme.secondary)
        batchLabel = batch
        let copy = button(AppText.pick("复制整组", "Copy Batch"), #selector(copyBatch), icon: "copy")
        let latest = button(AppText.pick("仅复制最新一张", "Copy Latest Only"), #selector(copyLatest))
        let clear = button(AppText.pick("清空", "Clear"), #selector(clearBatch), icon: "trash-2")
        batchButtons = [copy, latest, clear]
        let batchRow = NSStackView(views: [batch, NSView(), copy, latest, clear])
        batchRow.spacing = 8
        batchRow.alignment = .centerY
        batchRow.widthAnchor.constraint(equalToConstant: 700).isActive = true
        stack.addArrangedSubview(batchRow)
        stack.addArrangedSubview(detail(AppText.pick("按截图先后顺序粘贴，多图支持取决于接收应用。清空或退出会重置待粘贴组，已保存的 PNG 不会删除。",
            "Images are ordered oldest first. Multi-image paste depends on the receiving app. Clearing or quitting resets the batch; saved PNGs remain.")))
        stack.addArrangedSubview(divider())

        let language = NSPopUpButton()
        language.addItems(withTitles: [AppText.pick("跟随系统", "Follow System"), "简体中文", "English"])
        language.selectItem(at: AppLanguage.allCases.firstIndex(of: AppLanguage.storedPreference) ?? 0)
        language.target = self
        language.action = #selector(changeLanguage(_:))
        language.widthAnchor.constraint(equalToConstant: 180).isActive = true
        language.setAccessibilityLabel(AppText.pick("界面语言", "Interface language"))
        stack.addArrangedSubview(row(icon: "languages", title: AppText.pick("界面语言", "Interface language"),
            subtitle: AppText.pick("立即生效，无需重启", "Applies immediately, no restart needed"), controls: [language]))

        let login = NSButton(checkboxWithTitle: AppText.pick("登录时自动启动 HoverCapture", "Launch HoverCapture at login"), target: self, action: #selector(toggleLogin))
        login.contentTintColor = AppTheme.black
        loginButton = login
        let approval = button(AppText.pick("打开登录项设置", "Open Login Items"), #selector(openLoginItems))
        loginApprovalButton = approval
        let loginRow = NSStackView(views: [login, NSView(), approval])
        loginRow.widthAnchor.constraint(equalToConstant: 700).isActive = true
        stack.addArrangedSubview(loginRow)
        stack.addArrangedSubview(divider())
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let footer = NSStackView(views: [AppTheme.label("v\(version) · MIT", size: 12, color: AppTheme.secondary), NSView(),
            button(AppText.pick("打开截图文件夹", "Open Screenshots"), #selector(openFolder)),
            button(AppText.pick("关于", "About"), #selector(showAbout)),
            button(AppText.pick("退出", "Quit"), #selector(quit))])
        footer.spacing = 8
        footer.widthAnchor.constraint(equalToConstant: 700).isActive = true
        stack.addArrangedSubview(footer)
        stack.addArrangedSubview(detail(AppText.pick("截图仅在本机处理。关闭窗口后，HoverCapture 仍在菜单栏运行。",
            "Screenshots stay on your Mac. Close this window to keep running in the menu bar.")))
    }

    private func row(icon: String, title: String, subtitle: String = "", subtitleView: NSView? = nil,
                     controls: [NSView]) -> NSStackView {
        let image = NSImageView()
        image.image = AppTheme.icon(icon)
        image.contentTintColor = AppTheme.orange
        image.widthAnchor.constraint(equalToConstant: 22).isActive = true
        image.heightAnchor.constraint(equalToConstant: 22).isActive = true
        let labels = NSStackView(views: [AppTheme.label(title, weight: .semibold),
            subtitleView ?? AppTheme.label(subtitle, size: 12, color: AppTheme.secondary)])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 5
        let row = NSStackView(views: [image, labels, NSView()] + controls)
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY
        row.widthAnchor.constraint(equalToConstant: 700).isActive = true
        row.heightAnchor.constraint(equalToConstant: 46).isActive = true
        return row
    }

    private func detail(_ value: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: value)
        label.textColor = AppTheme.secondary
        label.font = .systemFont(ofSize: 12)
        label.widthAnchor.constraint(equalToConstant: 700).isActive = true
        return label
    }

    private func divider() -> NSBox {
        let line = NSBox()
        line.boxType = .separator
        line.widthAnchor.constraint(equalToConstant: 700).isActive = true
        return line
    }

    private func button(_ title: String, _ action: Selector, icon: String? = nil) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.contentTintColor = AppTheme.black
        if let icon {
            button.image = AppTheme.icon(icon)
            button.imagePosition = .imageLeading
        }
        return button
    }

    private func refreshSettings() {
        folderLabel?.stringValue = outputDirectory.path
        folderLabel?.toolTip = outputDirectory.path
        permissionLabel?.stringValue = CGPreflightScreenCaptureAccess()
            ? AppText.pick("已允许", "Allowed") : AppText.pick("需要授权", "Permission needed")
        permissionLabel?.textColor = CGPreflightScreenCaptureAccess() ? AppTheme.secondary : AppTheme.orange
        let loginStatus = SMAppService.mainApp.status
        loginButton?.state = LoginItemSettings.isRegistered(loginStatus) ? .on : .off
        loginButton?.title = loginStatus == .requiresApproval
            ? AppText.pick("登录时自动启动（待系统批准）", "Launch at login (approval needed)")
            : AppText.pick("登录时自动启动 HoverCapture", "Launch HoverCapture at login")
        loginApprovalButton?.isHidden = loginStatus != .requiresApproval
        batchLabel?.stringValue = AppText.pick("待粘贴 \(engine.batch.count) / \(engine.batch.capacity) 张", "Batch: \(engine.batch.count) / \(engine.batch.capacity)")
        batchButtons.forEach { $0.isEnabled = engine.batch.count > 0 }
        capacityField?.integerValue = engine.batch.capacity
        capacityStepper?.integerValue = engine.batch.capacity
    }

    @objc private func changeLanguage(_ sender: NSPopUpButton) {
        guard AppLanguage.allCases.indices.contains(sender.indexOfSelectedItem) else { return }
        AppLanguage.storedPreference = AppLanguage.allCases[sender.indexOfSelectedItem]
        shortcutButton?.cancelRecording()
        if let window = settingsWindow { populateSettings(window) }
        refreshSettings()
        restoreStatusIcon()
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        if let field = notification.object as? NSTextField, field === capacityField { changeCapacity(field) }
    }

    @objc private func changeCapacity(_ sender: NSControl) {
        let value = sender is NSStepper ? sender.integerValue : Int(sender.stringValue)
        guard let value, (1...20).contains(value) else {
            refreshSettings()
            showError(AppText.pick("请输入 1 到 20 之间的整数。", "Enter a whole number between 1 and 20."))
            return
        }
        let copied = engine.batch.setCapacity(value)
        defaults.set(engine.batch.capacity, forKey: "batchCapacity")
        refreshSettings()
        if !copied { clipboardError() }
    }

    @objc private func copyBatch() {
        if engine.batch.copyAll() {
            batchLabel?.stringValue = AppText.pick("已复制 \(engine.batch.count) 张", "Copied \(engine.batch.count) images")
        } else { clipboardError() }
    }

    @objc private func copyLatest() {
        if engine.batch.copyLatest() {
            batchLabel?.stringValue = AppText.pick("已复制最新一张", "Latest image copied")
        } else { clipboardError() }
    }

    @objc private func clearBatch() {
        engine.batch.clear()
        refreshSettings()
    }

    private func clipboardError() {
        showError(AppText.pick("复制失败，请重试；已保存的 PNG 文件不受影响。", "Could not copy. Try again; saved PNG files are unaffected."))
    }

    @objc private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = outputDirectory
        panel.prompt = AppText.pick("选择文件夹", "Choose Folder")
        if panel.runModal() == .OK, let url = panel.url {
            defaults.set(url.path, forKey: "outputDirectory")
            refreshSettings()
        }
    }

    @objc private func openFolder() {
        do {
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
            if !NSWorkspace.shared.open(outputDirectory) {
                showError(AppText.pick("无法打开截图文件夹。", "Could not open the screenshots folder."))
            }
        } catch { showError(error.localizedDescription) }
    }

    @objc private func openPrivacy() {
        if !CGPreflightScreenCaptureAccess() { _ = CGRequestScreenCaptureAccess() }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"),
           !NSWorkspace.shared.open(url) {
            showError(AppText.pick("请手动打开系统设置 → 隐私与安全性 → 屏幕录制。", "Open System Settings → Privacy & Security → Screen Recording."))
        }
        refreshSettings()
    }

    @objc private func toggleLogin() {
        do {
            try LoginItemSettings.toggle(SMAppService.mainApp)
        } catch { showError(error.localizedDescription) }
        refreshSettings()
        if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
    }

    @objc private func openLoginItems() { SMAppService.openSystemSettingsLoginItems() }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "HoverCapture",
            .credits: NSAttributedString(string: AppText.pick("共同作者：ChesterGe 与 GPT（OpenAI）\n开源窗口截图工具 · MIT 许可证\n界面图标：Lucide（ISC / MIT）", "Co-authors: ChesterGe and GPT (OpenAI)\nOpen-source window screenshots · MIT License\nInterface icons: Lucide (ISC / MIT)"))
        ])
    }

    @objc private func copyDiagnostic() {
        guard !isCapturing else {
            showError(AppText.pick("请等待截图完成后再复制诊断。", "Wait for capture to finish before copying the diagnosis."))
            return
        }
        guard let report = engine.lastDiagnostic else {
            showError(AppText.pick("请先用快捷键截图，再复制诊断。", "Capture with the shortcut before copying a diagnosis."))
            return
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.setString(report, forType: .string) else {
            showError(AppText.pick("诊断文字复制失败，请重试。", "Could not copy the diagnosis. Try again."))
            return
        }
        let alert = NSAlert()
        alert.messageText = AppText.pick("诊断文字已复制", "Diagnosis Copied")
        alert.informativeText = AppText.pick(
            "请把文字粘贴给开发者。包含版本、应用标识与窗口坐标，不含截图图片、窗口标题或文档路径，也不会自动上传。\n\n诊断文字已替换剪贴板内容。",
            "Paste the text to the developer. It includes versions, app identifiers and window coordinates, with no screenshot pixels, window titles, document paths or automatic uploads.\n\nThe diagnosis has replaced the clipboard contents.")
        if engine.batch.count > 0 {
            alert.informativeText += AppText.pick("可用“复制整组”重新复制截图。", " Use Copy Batch to copy the screenshots again.")
        }
        alert.alertStyle = .informational
        alert.addButton(withTitle: AppText.pick("好", "OK"))
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "HoverCapture"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: AppText.pick("好", "OK"))
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
