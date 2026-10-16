import AppKit
import CoreGraphics
import Darwin

// These checks create only their own short-lived windows. They do not post input,
// capture pixels, request permissions, or inspect another application's content.
@main
struct WindowHitNativeTests {
    @MainActor
    static func main() {
        do {
            try run(preflight: CommandLine.arguments.contains("--preflight"))
        } catch let failure as EnvironmentUnavailable {
            FileHandle.standardError.write(Data("Window hit GUI unavailable: \(failure.message)\n".utf8))
            exit(77)
        } catch {
            FileHandle.standardError.write(Data("Window hit native checks FAILED: \(error)\n".utf8))
            exit(1)
        }
    }

    @MainActor
    private static func run(preflight: Bool) throws {
        guard CGSessionCopyCurrentDictionary() != nil,
              CGMainDisplayID() != 0 else {
            throw EnvironmentUnavailable(message: "no graphical login session or main display")
        }
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.finishLaunching()
        guard let screen = NSScreen.main,
              screen.visibleFrame.width >= 400, screen.visibleFrame.height >= 300 else {
            throw EnvironmentUnavailable(message: "no usable AppKit screen")
        }

        // All frames and query points here are AppKit screen coordinates (origin
        // at the bottom left of the primary screen), not Quartz display points.
        let area = screen.visibleFrame
        let backFrame = NSRect(x: area.minX + (area.width - 360) / 2,
                               y: area.minY + (area.height - 240) / 3,
                               width: 360, height: 240)
        let back = makeWindow(frame: backFrame, color: .blue)
        defer { back.close() }
        back.orderFrontRegardless()
        settle(app)
        guard back.windowNumber > 0, back.isVisible else {
            throw EnvironmentUnavailable(message: "owned window could not connect to WindowServer")
        }
        if preflight {
            print("Window hit GUI preflight passed")
            return
        }

        let front = makeWindow(frame: backFrame.insetBy(dx: 40, dy: 30), color: .orange)
        defer { front.close() }
        front.orderFrontRegardless()
        settle(app)
        let backID = back.windowNumber
        let frontID = front.windowNumber
        var checks = 0
        var failures: [String] = []
        func check(_ name: String, _ condition: Bool, detail: String = "") throws {
            guard condition else {
                failures.append("\(name): \(detail)")
                return
            }
            checks += 1
        }
        func expectHit(_ name: String, at point: NSPoint, expected: Int, below: Int = 0) throws {
            // Window ordering and alpha hit masks cross the WindowServer boundary.
            // Wait briefly for the expected state instead of assuming synchronous flush.
            let deadline = Date().addingTimeInterval(2)
            var actual: Int
            repeat {
                settle(app)
                actual = NSWindow.windowNumber(at: point, belowWindowWithWindowNumber: below)
            } while actual != expected && Date() < deadline
            try check(name, actual == expected,
                      detail: "point=\(point), below=\(below), expected=\(expected), actual=\(actual)")
        }
        func expectSelected(_ name: String, at point: NSPoint, window expectedWindow: Int?,
                            reason expectedReason: CaptureSelectionReason = .window,
                            ownPID: Int32 = Int32.max, overlay: Int? = nil) throws {
            settle(app)
            let primaryID = CGMainDisplayID()
            guard let primaryScreen = NSScreen.screens.first(where: {
                ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == primaryID
            }) else { throw TestFailure(message: "\(name): primary AppKit screen unavailable") }
            let primaryBounds = CGDisplayBounds(primaryID)
            let quartzPoint = CGPoint(x: primaryBounds.minX + point.x - primaryScreen.frame.minX,
                                      y: primaryBounds.minY + primaryScreen.frame.maxY - point.y)
            guard let queryPoint = WindowHitTest.appKitPoint(from: quartzPoint,
                                                            primaryDisplayBounds: primaryBounds,
                                                            primaryScreenFrame: primaryScreen.frame),
                  let entries = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
                throw TestFailure(message: "\(name): coordinate conversion or CGWindow list unavailable")
            }
            // Preserve the real WindowServer order, layers, bounds, alpha and IDs.
            // Only our own fixture metadata is retained; no screenshot is taken.
            let windows = try entries.filter {
                ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == getpid()
            }.map { entry -> CaptureWindow in
                guard let id = entry[kCGWindowNumber as String] as? NSNumber,
                      let layer = entry[kCGWindowLayer as String] as? NSNumber,
                      let alpha = entry[kCGWindowAlpha as String] as? NSNumber,
                      let dictionary = entry[kCGWindowBounds as String] as? NSDictionary,
                      let bounds = CGRect(dictionaryRepresentation: dictionary),
                      bounds.minX.isFinite, bounds.minY.isFinite,
                      bounds.width.isFinite, bounds.height.isFinite,
                      bounds.width > 0, bounds.height > 0 else {
                    throw TestFailure(message: "\(name): malformed owned CGWindow metadata")
                }
                return CaptureWindow(id: id.uint32Value, ownerPID: getpid(), bounds: bounds,
                                     layer: layer.intValue, alpha: alpha.doubleValue)
            }
            let displays = NSScreen.screens.compactMap { screen -> CaptureDisplay? in
                guard let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value else {
                    return nil
                }
                return CaptureDisplay(id: id, bounds: CGDisplayBounds(id))
            }
            guard let display = displays.first(where: { $0.bounds.contains(quartzPoint) }) else {
                throw TestFailure(message: "\(name): no display contains converted point \(quartzPoint)")
            }
            let nativeID = NSWindow.windowNumber(at: queryPoint, belowWindowWithWindowNumber: 0)
            let decision = try CaptureSelection.decision(at: quartzPoint, windows: windows, displays: displays,
                                                         ownPID: ownPID, nativeWindowNumber: nativeID)
            let expected = expectedWindow.map { CaptureTarget.window(id: CGWindowID($0), ownerPID: getpid()) }
                ?? .screen(id: display.id)
            let nativeIndex = windows.firstIndex { Int($0.id) == nativeID }
            let overlayIndex = overlay.flatMap { id in windows.firstIndex { Int($0.id) == id } }
            let overlayPrecedesHit: Bool
            if let overlayIndex, let nativeIndex {
                overlayPrecedesHit = overlayIndex < nativeIndex
            } else {
                overlayPrecedesHit = overlay == nil
            }
            try check(name, decision.source == .nativeHit && decision.windowIndex == nativeIndex && nativeIndex != nil &&
                      decision.target == expected && decision.reason == expectedReason && overlayPrecedesHit,
                      detail: "native=\(nativeID), expected=\(expected) reason=\(expectedReason), actual=\(decision), ownedCG=\(windows), overlayPrecedesHit=\(overlayPrecedesHit)")
        }

        let point = NSPoint(x: front.frame.midX, y: front.frame.midY)
        let uncovered = NSPoint(x: back.frame.minX + 10, y: back.frame.minY + 10)
        try check("two owned windows have distinct positive IDs", backID > 0 && frontID > 0 && backID != frontID)
        let entries = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
        for (name, id) in [("back", backID), ("front", frontID)] {
            let entry = entries.first { ($0[kCGWindowNumber as String] as? NSNumber)?.intValue == id }
            try check("\(name) NSWindow ID matches owned CGWindow ID",
                      (entry?[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == getpid(),
                      detail: "NSWindow ID \(id) was not found with own PID \(getpid()) in CGWindowList")
        }
        try expectHit("frontmost opaque window", at: point, expected: frontID)
        try expectHit("uncovered back window", at: uncovered, expected: backID)
        try expectHit("below excludes front window", at: point, expected: backID, below: frontID)
        try expectSelected("selector captures native front window", at: point, window: frontID)
        try expectSelected("selector captures native uncovered window", at: uncovered, window: backID)
        try expectSelected("selector falls back for its own native window", at: point, window: nil,
                           reason: .ownWindow, ownPID: getpid())

        front.ignoresMouseEvents = true
        try expectHit("mouse-ignoring overlay is excluded", at: point, expected: backID)
        try expectSelected("selector skips mouse-ignoring ordinary overlay", at: point, window: backID, overlay: frontID)
        front.ignoresMouseEvents = false
        try expectHit("mouse acceptance restored", at: point, expected: frontID)
        try expectSelected("selector captures restored interactive window", at: point, window: frontID)
        front.level = .screenSaver
        front.orderFrontRegardless()
        try expectSelected("selector falls back for interactive high-layer window", at: point, window: nil,
                           reason: .unsupportedLayer)
        front.ignoresMouseEvents = true
        try expectSelected("selector bypasses real mouse-ignoring high-layer overlay", at: point, window: backID,
                           overlay: frontID)
        front.ignoresMouseEvents = false
        front.level = .floating
        front.orderFrontRegardless()
        front.alphaValue = 0
        settle(app)
        // Global visual alpha does not reliably change an opaque window's input
        // shape. Record it separately; clear-region assertions below stay required.
        print("Observation global-alpha-zero: hit=\(NSWindow.windowNumber(at: point, belowWindowWithWindowNumber: 0)) front=\(frontID) back=\(backID)")
        front.alphaValue = 1
        try expectHit("window alpha restored", at: point, expected: frontID)
        front.orderOut(nil)
        try expectHit("ordered-out window is excluded", at: point, expected: backID)
        front.orderFrontRegardless()
        try expectHit("reordered window is included", at: point, expected: frontID)

        front.isOpaque = false
        front.backgroundColor = .clear
        let view = HalfOpaqueView(frame: NSRect(origin: .zero, size: front.frame.size))
        front.contentView = view
        view.needsDisplay = true
        front.display()
        if let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
            view.cacheDisplay(in: view.bounds, to: bitmap)
            try check("fixture draws an opaque left half",
                      bitmap.colorAt(x: bitmap.pixelsWide / 4, y: bitmap.pixelsHigh / 2)?.alphaComponent == 1)
            try check("fixture draws a transparent right half",
                      bitmap.colorAt(x: 3 * bitmap.pixelsWide / 4, y: bitmap.pixelsHigh / 2)?.alphaComponent == 0)
        } else {
            try check("fixture bitmap is available", false)
        }
        let solidPoint = NSPoint(x: front.frame.minX + front.frame.width / 4, y: front.frame.midY)
        let clearPoint = NSPoint(x: front.frame.minX + 3 * front.frame.width / 4, y: front.frame.midY)
        try expectHit("drawn region of nonopaque window receives hit", at: solidPoint, expected: frontID)
        print("Observation opaque-to-nonopaque mutation: hit=\(NSWindow.windowNumber(at: clearPoint, belowWindowWithWindowNumber: 0)) front=\(frontID) back=\(backID)")

        // Also test a window configured as nonopaque before first ordering and
        // display, independently of the opaque-to-clear mutation above.
        front.orderOut(nil)
        let fresh = makeWindow(frame: front.frame, color: .clear)
        defer { fresh.close() }
        fresh.isOpaque = false
        let freshView = HalfOpaqueView(frame: NSRect(origin: .zero, size: fresh.frame.size))
        fresh.contentView = freshView
        fresh.orderFrontRegardless()
        fresh.display()
        try expectHit("fresh nonopaque drawn region receives hit", at: solidPoint, expected: fresh.windowNumber)
        try expectHit("fresh nonopaque clear region falls through", at: clearPoint, expected: backID)
        try expectSelected("selector captures fresh nonopaque drawn region", at: solidPoint, window: fresh.windowNumber)
        try expectSelected("selector bypasses fresh nonopaque clear region", at: clearPoint, window: backID,
                           overlay: fresh.windowNumber)
        freshView.drawLeftHalf = false
        freshView.needsDisplay = true
        fresh.display()
        try expectHit("redrawn nonopaque clear region falls through", at: solidPoint, expected: backID)
        try expectHit("redrawn nonopaque solid region receives hit", at: clearPoint, expected: fresh.windowNumber)
        try expectSelected("selector bypasses redrawn nonopaque clear region", at: solidPoint, window: backID,
                           overlay: fresh.windowNumber)
        try expectSelected("selector captures redrawn nonopaque drawn region", at: clearPoint, window: fresh.windowNumber)
        fresh.close()

        front.close()
        try expectHit("closed front window is excluded", at: point, expected: backID)
        back.close()
        settle(app)
        let afterClose = NSWindow.windowNumber(at: point, belowWindowWithWindowNumber: 0)
        try check("closed owned windows no longer hit", afterClose != backID && afterClose != frontID,
                  detail: "closed ID still returned: \(afterClose)")
        guard failures.isEmpty else {
            throw TestFailure(message: "\(checks) passed, \(failures.count) failed:\n" + failures.joined(separator: "\n"))
        }
        print("\(checks) native window hit checks passed")
    }

    @MainActor
    private static func makeWindow(frame: NSRect, color: NSColor) -> NSWindow {
        let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.hasShadow = false
        window.isOpaque = true
        window.backgroundColor = color
        window.level = .floating
        window.animationBehavior = .none
        return window
    }

    @MainActor
    private static func settle(_ app: NSApplication) {
        app.updateWindows()
        // AppKit defers display transactions until its event loop runs. A plain
        // Foundation run loop does not perform NSApplication's event processing.
        let deadline = Date().addingTimeInterval(0.05)
        while let event = app.nextEvent(matching: .any, until: deadline,
                                        inMode: .default, dequeue: true) {
            app.sendEvent(event)
            if Date() >= deadline { break }
        }
        app.updateWindows()
    }
}

private final class HalfOpaqueView: NSView {
    var drawLeftHalf = true
    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.current?.cgContext.clear(bounds)
        NSColor.orange.setFill()
        NSRect(x: drawLeftHalf ? bounds.minX : bounds.midX, y: bounds.minY,
               width: bounds.width / 2, height: bounds.height).fill()
    }
}

private struct EnvironmentUnavailable: Error {
    let message: String
}

private struct TestFailure: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}
