import AppKit
import Carbon

struct CaptureShortcut: Codable, Equatable {
    let keyCode: UInt32
    let modifiers: UInt32
    let keyLabel: String

    static let standard = CaptureShortcut(keyCode: UInt32(kVK_ANSI_S),
        modifiers: UInt32(controlKey | optionKey | cmdKey), keyLabel: "S")

    var label: String {
        [(controlKey, "⌃"), (optionKey, "⌥"), (shiftKey, "⇧"), (cmdKey, "⌘")]
            .filter { modifiers & UInt32($0.0) != 0 }.map { $0.1 }.joined() + keyLabel
    }

    static func from(_ event: NSEvent) -> CaptureShortcut? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !flags.intersection([.control, .option, .command]).isEmpty else { return nil }
        var modifiers: UInt32 = 0
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        let names: [UInt16: String] = [36: "↩", 48: "⇥", 49: "Space", 51: "⌫",
            53: "Esc", 123: "←", 124: "→", 125: "↓", 126: "↑",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
            98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12"]
        let label = names[event.keyCode] ?? event.charactersIgnoringModifiers?.uppercased() ?? ""
        guard !label.isEmpty else { return nil }
        return CaptureShortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers, keyLabel: label)
    }
}

final class HotKeyController {
    var onPress: (() -> Void)?
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private(set) var shortcut: CaptureShortcut?

    init() throws {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            let controller = Unmanaged<HotKeyController>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async { controller.onPress?() }
            return noErr
        }
        let result = InstallEventHandler(GetApplicationEventTarget(), callback, 1, &eventType,
            Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard result == noErr else { throw HotKeyError(status: result) }
    }

    func register(_ proposed: CaptureShortcut) throws {
        if shortcut == proposed, hotKey != nil { return }
        let previous = shortcut
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = nil
        let status = install(proposed)
        guard status == noErr else {
            if let previous {
                let restoreStatus = install(previous)
                if restoreStatus != noErr {
                    shortcut = nil
                    NSLog("HoverCapture: restoring previous shortcut failed: %d", restoreStatus)
                }
            }
            throw HotKeyError(status: status)
        }
        shortcut = proposed
    }

    private func install(_ shortcut: CaptureShortcut) -> OSStatus {
        let id = EventHotKeyID(signature: 0x484F5643, id: 1)
        return RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, id,
            GetApplicationEventTarget(), 0, &hotKey)
    }

    deinit {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
    }
}

struct HotKeyError: LocalizedError {
    let status: OSStatus
    var errorDescription: String? {
        AppText.pick("无法注册这个快捷键，请换一个组合键。错误码：\(status)",
            "This shortcut could not be registered. Try another combination. Error: \(status)")
    }
}

final class ShortcutButton: NSButton {
    var shortcut = CaptureShortcut.standard { didSet { title = shortcut.label } }
    var onChange: ((CaptureShortcut) -> Void)?
    private(set) var isRecording = false
    override var acceptsFirstResponder: Bool { true }

    @objc func beginRecording(_ sender: Any?) {
        isRecording = true
        title = AppText.pick("按下组合键… Esc 取消", "Press a shortcut… Esc to cancel")
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { super.keyDown(with: event); return }
        if event.keyCode == 53 { finish(); return }
        guard let proposed = CaptureShortcut.from(event) else { NSSound.beep(); return }
        finish()
        onChange?(proposed)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording else { return super.performKeyEquivalent(with: event) }
        keyDown(with: event)
        return true
    }

    override func resignFirstResponder() -> Bool { finish(); return super.resignFirstResponder() }
    func cancelRecording() { finish() }
    private func finish() { isRecording = false; title = shortcut.label }
}
