import AppKit
import CoreGraphics
import ServiceManagement

enum AppText {
    static var chinese: Bool { Locale.preferredLanguages.first?.hasPrefix("zh") == true }
    static func pick(_ zh: String, _ en: String) -> String { chinese ? zh : en }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let defaults = UserDefaults.standard
    private let engine = CaptureEngine()
    private var hotKeys: HotKeyController?
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var folderLabel: NSTextField?
    private var permissionLabel: NSTextField?
    private var shortcutButton: ShortcutButton?
    private var loginButton: NSButton?
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
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        restoreStatusIcon()
        statusItem.menu = NSMenu()
        statusItem.menu?.delegate = self
        do {
            hotKeys = try HotKeyController()
            try hotKeys?.register(savedShortcut)
            hotKeys?.onPress = { [weak self] in
                guard let self else { return }
                if self.shortcutButton?.isRecording == true {
                    self.shortcutButton?.cancelRecording()
                } else {
                    self.takeScreenshot()
                }
            }
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
        addItem(menu, AppText.pick("打开截图文件夹", "Open Screenshots Folder"), #selector(openFolder))
        addItem(menu, AppText.pick("屏幕录制权限…", "Screen Recording Permission…"), #selector(openPrivacy))
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
            defer { isCapturing = false }
            do {
                let result = try await engine.capture(directory: outputDirectory)
                if let warning = result.warning {
                    showError(warning)
                } else {
                    statusItem.button?.image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: AppText.pick("截图已保存并复制", "Screenshot saved and copied"))
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
        statusItem.button?.image = NSImage(systemSymbolName: "viewfinder", accessibilityDescription: "HoverCapture")
        statusItem.button?.image?.isTemplate = true
        statusItem.button?.toolTip = "HoverCapture — " + savedShortcut.label
    }

    @objc private func showSettings() {
        if settingsWindow == nil { buildSettings() }
        refreshSettings()
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func buildSettings() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 610, height: 600),
            styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = AppText.pick("HoverCapture 设置", "HoverCapture Settings")
        window.isReleasedWhenClosed = false
        window.center()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView?.addSubview(stack)
        if let content = window.contentView {
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 30),
                stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -30),
                stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 26),
            ])
        }
        let title = NSTextField(labelWithString: "HoverCapture")
        title.font = .systemFont(ofSize: 26, weight: .semibold)
        stack.addArrangedSubview(title)
        stack.addArrangedSubview(detail(AppText.pick("鼠标指向窗口，一键截图。空白处截所在屏幕。\n自动保存图片，同时复制到剪贴板。",
            "Point at a window and press your shortcut. Elsewhere, capture that display.\nEvery screenshot is saved and copied to the clipboard.")))
        stack.addArrangedSubview(divider())

        let permission = NSTextField(labelWithString: "")
        permissionLabel = permission
        stack.addArrangedSubview(row(label: AppText.pick("屏幕录制", "Screen Recording"),
            views: [permission, button(AppText.pick("打开设置", "Open Settings"), #selector(openPrivacy))]))

        let path = NSTextField(labelWithString: "")
        path.lineBreakMode = .byTruncatingMiddle
        path.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        folderLabel = path
        stack.addArrangedSubview(row(label: AppText.pick("保存位置", "Save location"),
            views: [path, button(AppText.pick("选择…", "Choose…"), #selector(chooseFolder))]))

        let recorder = ShortcutButton(title: savedShortcut.label, target: nil, action: nil)
        recorder.target = recorder
        recorder.action = #selector(ShortcutButton.beginRecording(_:))
        recorder.bezelStyle = .rounded
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
        stack.addArrangedSubview(row(label: AppText.pick("截图快捷键", "Keyboard shortcut"), views: [recorder]))
        stack.addArrangedSubview(detail(AppText.pick("点击快捷键按钮即可修改；按 Esc 取消。", "Click the shortcut to change it; press Esc to cancel.")))

        let login = NSButton(checkboxWithTitle: AppText.pick("登录时启动", "Launch at login"), target: self, action: #selector(toggleLogin))
        loginButton = login
        stack.addArrangedSubview(login)
        stack.addArrangedSubview(divider())
        stack.addArrangedSubview(row(label: "", views: [button(AppText.pick("打开文件夹", "Open Folder"), #selector(openFolder)),
            button(AppText.pick("退出应用", "Quit App"), #selector(quit))]))
        stack.addArrangedSubview(detail(AppText.pick("无需辅助功能权限、麦克风或网络。关闭此窗口后，应用仍在菜单栏运行。",
            "No Accessibility, microphone, or network access. Closing this window keeps the app in the menu bar.")))
        settingsWindow = window
    }

    private func row(label: String, views: [NSView]) -> NSStackView {
        let labelView = NSTextField(labelWithString: label)
        labelView.font = .systemFont(ofSize: 13, weight: .medium)
        labelView.widthAnchor.constraint(equalToConstant: 125).isActive = true
        let row = NSStackView(views: [labelView] + views)
        row.orientation = .horizontal
        row.spacing = 10
        row.alignment = .centerY
        row.widthAnchor.constraint(equalToConstant: 550).isActive = true
        return row
    }

    private func detail(_ value: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: value)
        label.textColor = .secondaryLabelColor
        label.font = .systemFont(ofSize: 12)
        label.widthAnchor.constraint(equalToConstant: 550).isActive = true
        return label
    }

    private func divider() -> NSBox {
        let line = NSBox()
        line.boxType = .separator
        line.widthAnchor.constraint(equalToConstant: 550).isActive = true
        return line
    }

    private func button(_ title: String, _ action: Selector) -> NSButton {
        NSButton(title: title, target: self, action: action)
    }

    private func refreshSettings() {
        folderLabel?.stringValue = outputDirectory.path
        folderLabel?.toolTip = outputDirectory.path
        permissionLabel?.stringValue = CGPreflightScreenCaptureAccess()
            ? AppText.pick("已允许", "Allowed") : AppText.pick("需要授权", "Permission needed")
        permissionLabel?.textColor = CGPreflightScreenCaptureAccess() ? .secondaryLabelColor : .systemOrange
        loginButton?.state = SMAppService.mainApp.status == .enabled ? .on : .off
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
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch { showError(error.localizedDescription) }
        refreshSettings()
        if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "HoverCapture", .applicationVersion: "0.1.0",
            .credits: NSAttributedString(string: AppText.pick("开源窗口截图工具 · MIT 许可证\n原生 macOS 应用，无需 Hammerspoon。", "Open-source window screenshots · MIT License\nA native macOS app. No Hammerspoon required."))
        ])
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
