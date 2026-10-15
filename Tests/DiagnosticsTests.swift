import CoreGraphics
import Foundation

@main
struct DiagnosticsTests {
    static func main() throws {
        let main = CaptureDisplay(id: 1, bounds: CGRect(x: 0, y: 0, width: 1440, height: 900))
        let left = CaptureDisplay(id: 2, bounds: CGRect(x: -1280, y: 0, width: 1280, height: 1024))
        let displays = [main, left]
        let point = CGPoint(x: 150, y: 150)
        let ownPID: Int32 = 99
        var checks = 0

        func check(_ name: String, _ condition: Bool) throws {
            guard condition else { throw TestFailure(message: name) }
            checks += 1
        }
        func window(_ id: UInt32, pid: Int32 = 42, layer: Int = 0,
                    bounds: CGRect = CGRect(x: 100, y: 100, width: 500, height: 400),
                    desktop: Bool = false, sharing: Int? = nil, title: Bool = false) -> CaptureWindow {
            CaptureWindow(id: id, ownerPID: pid, bounds: bounds, layer: layer, alpha: 1,
                          isDesktopElement: desktop, sharingState: sharing, hasTitle: title)
        }
        func decide(_ windows: [CaptureWindow], at location: CGPoint? = nil,
                    transparent: Set<CGWindowID> = []) throws -> CaptureDecision {
            try CaptureSelection.decision(at: location ?? point, windows: windows,
                                          displays: displays, ownPID: ownPID, transparentDockWindowIDs: transparent)
        }
        func expect(_ name: String, _ windows: [CaptureWindow], target: CaptureTarget,
                    reason: CaptureSelectionReason, index: Int?, skipped: [CGWindowID] = []) throws {
            let actual = try decide(windows, transparent: Set(skipped))
            try check(name, actual == CaptureDecision(target: target, reason: reason,
                                                     windowIndex: index, skippedDockWindowIDs: skipped))
        }
        func report(_ windows: [CaptureWindow], decision: CaptureDecision,
                    location: CGPoint? = nil) -> String {
            CaptureDiagnostics.report(point: location ?? point, windows: windows, displays: displays,
                                      decision: decision,
                                      ownerBundleIDs: [42: "com.apple.finder", 55: "com.apple.dock",
                                                       77: "org.example.unrelated"], ownPID: ownPID,
                                      appVersion: "0.2.2", buildVersion: "6", systemVersion: "26.1 (25B78)",
                                      date: Date(timeIntervalSince1970: 0))
        }

        let finder = window(11, title: true)
        let away = window(12, pid: 77, bounds: CGRect(x: 700, y: 100, width: 300, height: 300))
        try expect("original index survives skipped unrelated window", [away, finder],
                   target: .window(id: 11, ownerPID: 42), reason: .window, index: 1)
        try expect("own window explains screen selection", [window(13, pid: ownPID), finder],
                   target: .screen(id: 1), reason: .ownWindow, index: 0)
        try expect("unsupported layer explains screen selection", [window(14, layer: 101), finder],
                   target: .screen(id: 1), reason: .unsupportedLayer, index: 0)
        try expect("desktop process explains screen selection", [window(15, pid: 55, desktop: true), finder],
                   target: .screen(id: 1), reason: .desktopElement, index: 0)
        try expect("empty area has no decisive window", [away],
                   target: .screen(id: 1), reason: .noWindow, index: nil)

        let tracking = window(20, pid: 55, layer: 20, bounds: main.bounds, desktop: true, sharing: 0)
        try expect("transparent Dock probe reports skip", [tracking, finder],
                   target: .window(id: 11, ownerPID: 42), reason: .window, index: 1, skipped: [20])
        try expect("tracking-only desktop preserves skip", [tracking],
                   target: .screen(id: 1), reason: .noWindow, index: nil, skipped: [20])
        let missingSharing = window(21, pid: 55, layer: 20, bounds: main.bounds, desktop: true)
        try expect("missing sharing state is not the exact tracking signature", [missingSharing, finder],
                   target: .screen(id: 1), reason: .desktopElement, index: 0)
        let nearBounds = window(22, pid: 55, layer: 20,
                                bounds: CGRect(x: 0, y: 0, width: 1440, height: 899),
                                desktop: true, sharing: 0)
        try expect("near-full-display bounds remain a blocker", [nearBounds, finder],
                   target: .screen(id: 1), reason: .desktopElement, index: 0)
        try expect("later blocker retains earlier skip", [tracking, missingSharing, finder],
                   target: .screen(id: 1), reason: .desktopElement, index: 1, skipped: [20])

        let dockStrip = window(23, pid: 55, layer: 20,
                               bounds: CGRect(x: 100, y: 800, width: 1000, height: 100),
                               desktop: true, sharing: 0)
        var frozenWindows = [missingSharing, finder, away, dockStrip]
        let diagnosis = report(frozenWindows, decision: try decide(frozenWindows))
        try check("report distinguishes release build and OS", diagnosis.contains("appVersion=0.2.2 build=6") &&
                  diagnosis.contains("system=26.1 (25B78)"))
        try check("report uses supplied capture time and pointer", diagnosis.contains("capturedAt=1970-01-01T00:00:00Z ownPID=99") &&
                  diagnosis.contains("pointer=(150.0,150.0)"))
        try check("report records exact decisive surface", diagnosis.contains("target=screen id=1 reason=desktopElement") &&
                  diagnosis.contains("decisiveWindowIndex=0"))
        try check("report retains window behind blocker", diagnosis.contains("window[1] id=11 pid=42 bundle=com.apple.finder"))
        try check("report omits unrelated apps", !diagnosis.contains("window[2]") &&
                  !diagnosis.contains("org.example.unrelated"))
        try check("report keeps Dock geometry away from pointer", diagnosis.contains("window[3] id=23") &&
                  diagnosis.contains("atPointer=false bounds=(100.0,800.0,1000.0,100.0)"))
        try check("report preserves missing sharing metadata", diagnosis.contains("window[0] id=21") &&
                  diagnosis.contains("sharing=unknown hasTitle=false dock=true"))
        try check("report preserves original and relevant counts", diagnosis.contains("displayCount=2 windowCount=4") &&
                  diagnosis.contains("relevantWindowCount=3"))
        let finderRow = diagnosis.split(separator: "\n").first { $0.hasPrefix("window[1]") }
        try check("title metadata is Boolean only", finderRow ==
                  "window[1] id=11 pid=42 bundle=com.apple.finder layer=0 alpha=1.0 sharing=unknown hasTitle=true dock=false atPointer=true bounds=(100.0,100.0,500.0,400.0)")
        frozenWindows.removeAll()
        try check("retained report does not depend on later window list", diagnosis.contains("window[0] id=21") &&
                  diagnosis.contains("windowCount=4"))

        let unknown = window(24, pid: 1234, layer: 20)
        let unknownReport = report([unknown, finder], decision: try decide([unknown, finder]))
        try check("unknown bundle is explicit", unknownReport.contains("pid=1234 bundle=unknown"))
        let skipReport = report([tracking, finder], decision: try decide([tracking, finder], transparent: [20]))
        try check("report explains transparent Dock skip", skipReport.contains("skippedDockWindowIDs=20") &&
                  skipReport.contains("decisiveWindowIndex=1") && skipReport.contains("target=window id=11 pid=42 reason=window"))
        let emptyReport = report([], decision: try decide([]))
        try check("empty-area report is unambiguous", emptyReport.contains("reason=noWindow") &&
                  emptyReport.contains("decisiveWindowIndex=none") && emptyReport.contains("relevantWindowCount=0"))

        for alpha in [DockAlphaResult.transparent, .visible, .unavailable] {
            let probeReport = CaptureDiagnostics.report(
                point: point, windows: [tracking, finder], displays: displays,
                decision: try decide([tracking, finder], transparent: alpha == .transparent ? [20] : []),
                ownerBundleIDs: [:], ownPID: ownPID, appVersion: "0.2.2", buildVersion: "7", systemVersion: "26.1",
                dockProbes: [20: DockProbeResult(alpha: alpha, detail: alpha == .unavailable ? "windowUnavailable" : "sampled")])
            try check("\(alpha) probe outcome is copyable", probeReport.hasPrefix("HoverCapture target diagnosis v2") &&
                      probeReport.contains("dockProbe id=20 alpha=\(alpha.rawValue) detail="))
        }

        let negativePoint = CGPoint(x: -500, y: 150)
        let leftWindow = window(25, bounds: CGRect(x: -600, y: 100, width: 500, height: 400))
        let leftReport = report([leftWindow], decision: try decide([leftWindow], at: negativePoint), location: negativePoint)
        try check("negative coordinates retain original coordinate space", leftReport.contains("pointer=(-500.0,150.0)") &&
                  leftReport.contains("display id=2 bounds=(-1280.0,0.0,1280.0,1024.0)") &&
                  leftReport.contains("bounds=(-600.0,100.0,500.0,400.0)"))

        // A later surface is not validated once an earlier blocker wins. Its metadata
        // must still be copyable, even if it contains a non-finite numeric value.
        let invalidLater = CaptureWindow(id: 26, ownerPID: 55, bounds: main.bounds,
                                         layer: 20, alpha: .nan, isDesktopElement: true)
        let invalidReport = report([missingSharing, invalidLater], decision: try decide([missingSharing, invalidLater]))
        try check("non-finite later metadata does not prevent report creation", invalidReport.contains("window[1] id=26") &&
                  invalidReport.contains("alpha=nan"))

        do {
            _ = try decide([invalidLater, finder])
            throw TestFailure(message: "invalid leading metadata unexpectedly selected a target")
        } catch let error as CaptureSelectionError {
            try check("decision retains invalid-window error", error == .invalidWindow)
        }
        do {
            _ = try decide([], at: CGPoint(x: CGFloat.infinity, y: 0))
            throw TestFailure(message: "invalid pointer unexpectedly selected a target")
        } catch let error as CaptureSelectionError {
            try check("decision retains invalid-pointer error", error == .invalidPointer)
        }
        print("Diagnostics tests: \(checks) passed, 0 failed")
    }
}

private struct TestFailure: Error {
    let message: String
}
