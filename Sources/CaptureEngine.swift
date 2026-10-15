import AppKit
import ScreenCaptureKit

struct CaptureResult {
    let fileURL: URL?
    let clipboardCopied: Bool
    let warning: String?
    let kind: String
}

@MainActor
final class CaptureEngine {
    let batch = CaptureBatch()
    private(set) var lastDiagnostic: String?

    func clearDiagnostic() { lastDiagnostic = nil }

    func capture(directory: URL) async throws -> CaptureResult {
        clearDiagnostic()
        guard CGPreflightScreenCaptureAccess() else {
            throw failure("请在系统设置中允许 HoverCapture 录制屏幕，然后完全退出并重新打开软件。",
                          "Allow Screen Recording for HoverCapture in System Settings, then quit and reopen the app.")
        }
        // Freeze pointer, window order and display IDs before the first await.
        // Moving the pointer while ScreenCaptureKit responds cannot retarget it.
        let target = try snapshotTarget()
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            throw failure("无法读取可截图内容：\(error.localizedDescription)",
                          "Could not read shareable content: \(error.localizedDescription)")
        }

        let filter: SCContentFilter
        let kind: String
        switch target {
        case let .window(id, ownerPID):
            guard let window = content.windows.first(where: {
                $0.windowID == id && $0.owningApplication?.processID == ownerPID && $0.isOnScreen
            }) else {
                throw failure("目标窗口已关闭、隐藏或无法截图，请重试。未改截全屏。",
                              "The selected window closed, became hidden, or is unavailable. Try again. No screen capture was taken.")
            }
            filter = SCContentFilter(desktopIndependentWindow: window)
            kind = "Window"
        case let .screen(id):
            guard let display = content.displays.first(where: { $0.displayID == id }) else {
                throw failure("鼠标所在的显示器已断开或无法截图，请重试。",
                              "The display under the pointer disconnected or is unavailable. Try again.")
            }
            filter = SCContentFilter(display: display, excludingWindows: [])
            filter.includeMenuBar = true
            kind = "Screen"
        }

        let scale = CGFloat(filter.pointPixelScale)
        let width = ceil(filter.contentRect.width * scale)
        let height = ceil(filter.contentRect.height * scale)
        guard scale > 0, width.isFinite, height.isFinite,
              width > 0, height > 0, width < CGFloat(Int.max), height < CGFloat(Int.max) else {
            throw failure("无法读取截图尺寸，请重试。", "Could not read valid capture dimensions. Try again.")
        }
        let configuration = SCStreamConfiguration()
        configuration.width = Int(width)
        configuration.height = Int(height)
        configuration.captureResolution = .best
        configuration.showsCursor = false
        configuration.capturesAudio = false
        if kind == "Window" {
            configuration.ignoreShadowsSingleWindow = true
            configuration.ignoreGlobalClipSingleWindow = true
            configuration.includeChildWindows = false
        }

        let image: CGImage
        do {
            image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        } catch {
            throw failure("截图失败（\(kind)）：\(error.localizedDescription)",
                          "Capture failed (\(kind)): \(error.localizedDescription)")
        }
        return try deliver(image, directory: directory, kind: kind)
    }

    private func snapshotTarget() throws -> CaptureTarget {
        guard let point = CGEvent(source: nil)?.location else {
            throw failure("无法读取鼠标位置。", "Could not read the pointer position.")
        }
        // Use the primary display, not NSScreen.main (the keyboard-focused screen).
        // below=0 queries the true frontmost mouse recipient, including other apps.
        let primaryID = CGMainDisplayID()
        let primaryScreen = NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == primaryID
        }
        let appKitPoint = primaryScreen.flatMap {
            WindowHitTest.appKitPoint(from: point, primaryDisplayBounds: CGDisplayBounds(primaryID),
                                      primaryScreenFrame: $0.frame)
        }
        let nativeHit = CaptureWindowHit(number: appKitPoint.map {
            NSWindow.windowNumber(at: $0, belowWindowWithWindowNumber: 0)
        }, appKitPoint: appKitPoint)
        guard let entries = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
            throw failure("无法读取窗口列表，请检查屏幕录制权限。",
                          "Could not read the window list. Check Screen Recording permission.")
        }
        var windows: [CaptureWindow] = []
        var desktopProcesses: [Int32: Bool] = [:]
        var ownerBundleIDs: [Int32: String] = [:]
        for entry in entries {
            guard let id = entry[kCGWindowNumber as String] as? NSNumber,
                  let pid = entry[kCGWindowOwnerPID as String] as? NSNumber,
                  let layer = entry[kCGWindowLayer as String] as? NSNumber,
                  let alpha = entry[kCGWindowAlpha as String] as? NSNumber,
                  let bounds = entry[kCGWindowBounds as String] as? [String: Any],
                  let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary) else {
                throw failure("窗口信息不完整，已取消本次截图，请重试。",
                              "The window list was incomplete. Capture was canceled; try again.")
            }
            let ownerPID = pid.int32Value
            if desktopProcesses[ownerPID] == nil {
                let bundleID = NSRunningApplication(processIdentifier: ownerPID)?.bundleIdentifier
                desktopProcesses[ownerPID] = bundleID == "com.apple.dock"
                if let bundleID { ownerBundleIDs[ownerPID] = bundleID }
            }
            windows.append(CaptureWindow(id: id.uint32Value, ownerPID: ownerPID,
                                         bounds: rect, layer: layer.intValue, alpha: alpha.doubleValue,
                                         isDesktopElement: desktopProcesses[ownerPID] == true,
                                         sharingState: (entry[kCGWindowSharingState as String] as? NSNumber)?.intValue,
                                         hasTitle: (entry[kCGWindowName as String] as? String)?.isEmpty == false))
        }

        var displayCount: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &displayCount) == .success, displayCount > 0 else {
            throw failure("无法读取显示器列表。", "Could not read the display list.")
        }
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        guard CGGetActiveDisplayList(displayCount, &displayIDs, &displayCount) == .success else {
            throw failure("显示器配置发生变化，请重试。", "The display configuration changed. Try again.")
        }
        let displays = displayIDs.prefix(Int(displayCount)).map {
            CaptureDisplay(id: $0, bounds: CGDisplayBounds($0))
        }
        do {
            let ownPID = ProcessInfo.processInfo.processIdentifier
            let decision = try CaptureSelection.decision(at: point, windows: windows, displays: displays,
                                                         ownPID: ownPID, nativeWindowNumber: nativeHit.number)
            lastDiagnostic = CaptureDiagnostics.report(
                point: point, windows: windows, displays: displays, decision: decision,
                ownerBundleIDs: ownerBundleIDs, ownPID: ownPID,
                appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
                buildVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
                systemVersion: ProcessInfo.processInfo.operatingSystemVersionString, nativeHit: nativeHit)
            return decision.target
        } catch {
            throw failure("无法确定有效的截图目标（\(error)），已取消截图。",
                          "Could not determine a valid capture target (\(error)). Capture was canceled.")
        }
    }

    private func deliver(_ image: CGImage, directory: URL, kind: String) throws -> CaptureResult {
        guard let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            // Keep direct image copying available even if PNG encoding fails.
            // The unencoded image is never retained in the batch.
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            let copied = pasteboard.writeObjects([NSImage(cgImage: image, size: .zero)])
            let warning = captureText("无法编码 PNG，截图未保存或加入批次。", "Could not encode PNG. The screenshot was not saved or added to the batch.")
            guard copied else {
                throw failure("无法编码 PNG，且复制到剪贴板失败。", "Could not encode PNG or copy the image to the clipboard.")
            }
            return CaptureResult(fileURL: nil, clipboardCopied: true, warning: warning, kind: kind)
        }
        var warnings: [String] = []
        var fileURL: URL?
        do {
            guard directory.isFileURL else {
                throw failure("保存位置必须是本地文件夹。", "The save location must be a local folder.")
            }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss-SSS"
            let filename = "\(kind)-\(formatter.string(from: Date()))-\(UUID().uuidString.prefix(8)).png"
            let destination = directory.appendingPathComponent(filename)
            try png.write(to: destination, options: .withoutOverwriting)
            fileURL = destination
        } catch {
            warnings.append(captureText("保存失败（\(directory.path)）：\(error.localizedDescription)",
                                        "Could not save to \(directory.path): \(error.localizedDescription)"))
        }
        // PNG bytes stay available for copying even if the destination is unwritable.
        let copied = batch.append(pngData: png, fileURL: fileURL)
        if !copied {
            warnings.append(captureText("复制批次到剪贴板失败，可在设置中重试。", "Could not copy the batch to the clipboard. Retry from Settings."))
        }
        guard copied || fileURL != nil else {
            throw CaptureEngineError(message: warnings.joined(separator: "\n"))
        }
        return CaptureResult(fileURL: fileURL, clipboardCopied: copied,
                             warning: warnings.isEmpty ? nil : warnings.joined(separator: "\n"), kind: kind)
    }

    private func failure(_ chinese: String, _ english: String) -> CaptureEngineError {
        CaptureEngineError(message: captureText(chinese, english))
    }
}

private func captureText(_ chinese: String, _ english: String) -> String {
    AppText.pick(chinese, english)
}

private struct CaptureEngineError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
