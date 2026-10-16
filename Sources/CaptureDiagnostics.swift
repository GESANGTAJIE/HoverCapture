import Foundation
import CoreGraphics

enum CaptureDiagnostics {
    // Deliberately accepts no window titles, owner names, file paths or pixels.
    static func report(point: CGPoint, windows: [CaptureWindow], displays: [CaptureDisplay],
                       decision: CaptureDecision, ownerBundleIDs: [Int32: String], ownPID: Int32,
                       appVersion: String, buildVersion: String, systemVersion: String,
                       date: Date = Date(), nativeHit: CaptureWindowHit? = nil) -> String {
        let target: String
        switch decision.target {
        case let .window(id, ownerPID): target = "window id=\(id) pid=\(ownerPID)"
        case let .screen(id): target = "screen id=\(id)"
        }
        var lines = [
            "HoverCapture target diagnosis v4",
            "appVersion=\(appVersion) build=\(buildVersion)",
            "system=\(systemVersion)",
            "capturedAt=\(ISO8601DateFormatter().string(from: date)) ownPID=\(ownPID)",
            "pointer=(\(point.x),\(point.y))",
            "target=\(target) reason=\(decision.reason.rawValue)",
            "decisiveWindowIndex=\(decision.windowIndex.map(String.init) ?? "none")",
            "selectionSource=\(decision.source.rawValue)",
            "bypassedWindowIDs=\(decision.bypassedWindowIDs.map(String.init).joined(separator: ","))",
            "displayCount=\(displays.count) windowCount=\(windows.count)"
        ]
        for display in displays {
            lines.append("display id=\(display.id) bounds=\(rect(display.bounds))")
        }
        let hitIndex = WindowHitTest.matchedIndex(for: nativeHit?.number, at: point, windows: windows)
        let appKitPoint = nativeHit?.appKitPoint.map { "(\($0.x),\($0.y))" } ?? "unavailable"
        lines.append("nativeHit windowNumber=\(nativeHit?.number.map(String.init) ?? "unavailable") " +
                     "matchedWindowIndex=\(hitIndex.map(String.init) ?? "none") appKitPoint=\(appKitPoint)")
        // Include windows behind the blocker plus Dock surfaces away from the pointer.
        // Original indices preserve WindowServer order. Other unrelated apps are omitted.
        let relevant = windows.enumerated().filter { index, window in
            contains(window.bounds, point) || window.isDesktopElement || index == decision.windowIndex
        }
        lines.append("relevantWindowCount=\(relevant.count)")
        for (index, window) in relevant {
            lines.append("window[\(index)] id=\(window.id) pid=\(window.ownerPID) " +
                         "bundle=\(ownerBundleIDs[window.ownerPID] ?? "unknown") " +
                         "layer=\(window.layer) alpha=\(window.alpha) " +
                         "sharing=\(window.sharingState.map(String.init) ?? "unknown") " +
                         "hasTitle=\(window.hasTitle) dock=\(window.isDesktopElement) " +
                         "atPointer=\(contains(window.bounds, point)) bounds=\(rect(window.bounds))")
        }
        lines.append("No screenshot pixels, window titles, document paths or automatic uploads.")
        return lines.joined(separator: "\n")
    }

    private static func rect(_ rect: CGRect) -> String {
        "(\(rect.origin.x),\(rect.origin.y),\(rect.size.width),\(rect.size.height))"
    }

    private static func contains(_ rect: CGRect, _ point: CGPoint) -> Bool {
        point.x >= rect.minX && point.x < rect.maxX && point.y >= rect.minY && point.y < rect.maxY
    }
}
