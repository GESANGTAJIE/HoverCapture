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
        func check(_ name: String, _ condition: Bool, detail: String = "") throws {
            guard condition else { throw TestFailure(message: "\(name): \(detail)") }
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

        front.ignoresMouseEvents = true
        try expectHit("mouse-ignoring overlay is excluded", at: point, expected: backID)
        front.ignoresMouseEvents = false
        try expectHit("mouse acceptance restored", at: point, expected: frontID)
        front.alphaValue = 0
        try expectHit("zero-alpha window is excluded", at: point, expected: backID)
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
        front.displayIfNeeded()
        let solidPoint = NSPoint(x: front.frame.minX + front.frame.width / 4, y: front.frame.midY)
        let clearPoint = NSPoint(x: front.frame.minX + 3 * front.frame.width / 4, y: front.frame.midY)
        try expectHit("drawn region of nonopaque window receives hit", at: solidPoint, expected: frontID)
        try expectHit("clear region falls through to underlying window", at: clearPoint, expected: backID)

        front.close()
        try expectHit("closed front window is excluded", at: point, expected: backID)
        back.close()
        settle(app)
        let afterClose = NSWindow.windowNumber(at: point, belowWindowWithWindowNumber: 0)
        try check("closed owned windows no longer hit", afterClose != backID && afterClose != frontID,
                  detail: "closed ID still returned: \(afterClose)")
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
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    }
}

private final class HalfOpaqueView: NSView {
    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.current?.cgContext.clear(bounds)
        NSColor.orange.setFill()
        NSRect(x: bounds.minX, y: bounds.minY, width: bounds.width / 2, height: bounds.height).fill()
    }
}

private struct EnvironmentUnavailable: Error {
    let message: String
}

private struct TestFailure: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}
