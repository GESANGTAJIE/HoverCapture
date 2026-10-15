import CoreGraphics
import Foundation

@main
struct TahoeDockTests {
    static func main() throws {
        // Window metadata and pointer from the failed RC3 / Tahoe 26.1 report.
        // Native hit numbers below are synthetic inputs, NOT observed Tahoe results.
        let display = CaptureDisplay(id: 1, bounds: CGRect(x: 0, y: 0, width: 1440, height: 900))
        let point = CGPoint(x: 783.45703125, y: 91.2890625)
        let dock = CaptureWindow(id: 16, ownerPID: 625, bounds: display.bounds,
                                 layer: 20, alpha: 1, isDesktopElement: true,
                                 sharingState: 1, hasTitle: true)
        let finder = CaptureWindow(id: 6604, ownerPID: 628,
                                   bounds: CGRect(x: 420, y: 67, width: 920, height: 436),
                                   layer: 0, alpha: 1, sharingState: 1, hasTitle: true)
        let notes = CaptureWindow(id: 6602, ownerPID: 8750,
                                  bounds: CGRect(x: 127, y: 31, width: 918, height: 792),
                                  layer: 0, alpha: 1, sharingState: 1, hasTitle: true)
        let desktop = CaptureWindow(id: 27, ownerPID: 628, bounds: display.bounds,
                                    layer: -2147483603, alpha: 1, sharingState: 1)
        let dockDesktop = CaptureWindow(id: 17, ownerPID: 625, bounds: display.bounds,
                                        layer: -2147483624, alpha: 1, isDesktopElement: true,
                                        sharingState: 1, hasTitle: true)
        let wallpaper = CaptureWindow(id: 1251, ownerPID: 645, bounds: display.bounds,
                                      layer: -2147483625, alpha: 1, sharingState: 1, hasTitle: true)
        let background = CaptureWindow(id: 2, ownerPID: 404, bounds: display.bounds,
                                       layer: -2147483626, alpha: 1, sharingState: 1, hasTitle: true)
        var checks = 0
        func check(_ name: String, _ condition: Bool) throws {
            guard condition else { throw TestFailure(message: name) }
            checks += 1
        }
        func decide(_ windows: [CaptureWindow], hit: Int? = 6604, at location: CGPoint? = nil,
                    displays: [CaptureDisplay]? = nil) throws -> CaptureDecision {
            try CaptureSelection.decision(at: location ?? point, windows: windows,
                                          displays: displays ?? [display], ownPID: 8738,
                                          nativeWindowNumber: hit)
        }
        for (name, windows) in [
            ("reported relevant-window order", [dock, finder, notes, desktop, dockDesktop, wallpaper, background]),
            ("minimal Dock and Finder reproduction", [dock, finder])
        ] {
            let result = try decide(windows)
            try check("\(name) with native Finder hit", result.target == .window(id: 6604, ownerPID: 628))
            try check("\(name) records skip and original index", result.skippedDockWindowIDs == [16] && result.windowIndex == 1)
        }
        for hit: Int? in [nil, 0, -1, Int.max, Int(UInt32.max) + 1, 9999, 16] {
            let result = try decide([dock, finder], hit: hit)
            try check("unusable or Dock hit \(String(describing: hit)) keeps screen fallback",
                      result.target == .screen(id: 1) && result.reason == .desktopElement && result.skippedDockWindowIDs.isEmpty)
        }
        for state: Int? in [nil, 0, 1, 2] {
            for title in [false, true] {
                var variant = dock
                variant.sharingState = state
                variant.hasTitle = title
                try check("sharing \(String(describing: state)), title \(title) do not override native hit",
                          try decide([variant, finder]).target == .window(id: 6604, ownerPID: 628))
            }
        }
        let duplicateResult = try decide([dock, finder, finder])
        try check("ambiguous native ID does not authorize skip", duplicateResult.target == .screen(id: 1) &&
                  duplicateResult.skippedDockWindowIDs.isEmpty)

        for (name, bounds, alpha, pid) in [
            ("moved away", CGRect(x: 0, y: 500, width: 500, height: 300), 1.0, Int32(628)),
            ("zero width", CGRect(x: point.x, y: point.y, width: 0, height: 300), 1.0, Int32(628)),
            ("negative width", CGRect(x: point.x, y: point.y, width: -500, height: 300), 1.0, Int32(628)),
            ("nonfinite bounds", CGRect(x: CGFloat.nan, y: 0, width: 500, height: 300), 1.0, Int32(628)),
            ("transparent", finder.bounds, 0.0, Int32(628)),
            ("nonfinite alpha", finder.bounds, Double.nan, Int32(628)),
            ("invalid owner", finder.bounds, 1.0, Int32(0))
        ] {
            let changed = CaptureWindow(id: finder.id, ownerPID: pid, bounds: bounds, layer: 0, alpha: alpha)
            try check("\(name) native target is not matched",
                      WindowHitTest.matchedIndex(for: 6604, at: point, windows: [dock, changed]) == nil)
            try check("\(name) target cannot expose behind Dock", try decide([dock, changed]).target == .screen(id: 1))
        }
        let maxID = CaptureWindow(id: UInt32.max, ownerPID: 628, bounds: finder.bounds, layer: 0, alpha: 1)
        try check("largest exact UInt32 native ID is supported",
                  try decide([dock, maxID], hit: Int(UInt32.max)).target == .window(id: UInt32.max, ownerPID: 628))
        try check("invalid pointer cannot match native hit", WindowHitTest.matchedIndex(
            for: 6604, at: CGPoint(x: CGFloat.nan, y: 0), windows: [finder]) == nil)
        try check("right boundary cannot match native hit", WindowHitTest.matchedIndex(
            for: 6604, at: CGPoint(x: finder.bounds.maxX, y: point.y), windows: [finder]) == nil)

        let menu = CaptureWindow(id: 100, ownerPID: 628, bounds: finder.bounds, layer: 101, alpha: 1)
        let before = try decide([menu, dock, finder])
        try check("menu ahead of Dock blocks before skip", before.target == .screen(id: 1) && before.skippedDockWindowIDs.isEmpty)
        let behind = try decide([dock, menu, finder])
        try check("menu behind Dock is still a blocker", behind.target == .screen(id: 1) &&
                  behind.reason == .unsupportedLayer && behind.windowIndex == 1 && behind.skippedDockWindowIDs == [16])
        let popup = CaptureWindow(id: 101, ownerPID: 628, bounds: finder.bounds, layer: 8, alpha: 1)
        let nativeAbove = try decide([popup, dock, finder], hit: 101)
        try check("native hit ahead of Dock keeps front popup", nativeAbove.target == .window(id: 101, ownerPID: 628) &&
                  nativeAbove.skippedDockWindowIDs.isEmpty)
        let ignoredAbove = try decide([desktop, dock, finder], hit: 27)
        try check("native match before Dock never authorizes later skip", ignoredAbove.target == .screen(id: 1) &&
                  ignoredAbove.skippedDockWindowIDs.isEmpty)
        let own = CaptureWindow(id: 102, ownerPID: 8738, bounds: finder.bounds, layer: 0, alpha: 1)
        try check("own window behind Dock still captures screen", try decide([dock, own, finder], hit: 102).reason == .ownWindow)
        for (name, blocker) in [
            ("other owner", CaptureWindow(id: 103, ownerPID: 700, bounds: display.bounds, layer: 20, alpha: 1)),
            ("Mission Control", CaptureWindow(id: 104, ownerPID: 625, bounds: display.bounds, layer: 18, alpha: 1, isDesktopElement: true)),
            ("partial Dock", CaptureWindow(id: 105, ownerPID: 625, bounds: finder.bounds, layer: 20, alpha: 1, isDesktopElement: true))
        ] {
            let result = try decide([blocker, finder])
            try check("\(name) remains blocked", result.target == .screen(id: 1) && result.skippedDockWindowIDs.isEmpty)
        }
        let secondDock = CaptureWindow(id: 106, ownerPID: 625, bounds: display.bounds, layer: 20, alpha: 1, isDesktopElement: true)
        let twoDock = try decide([dock, secondDock, finder])
        try check("two full-display Dock surfaces before native target are skipped in order",
                  twoDock.skippedDockWindowIDs == [16, 106] && twoDock.target == .window(id: 6604, ownerPID: 628))
        let dockHit = try decide([dock, secondDock, finder], hit: 106)
        try check("native Dock hit stops at that Dock surface", dockHit.target == .screen(id: 1) &&
                  dockHit.windowIndex == 1 && dockHit.skippedDockWindowIDs == [16])
        try check("ordinary windows retain front-to-back ordering", try decide([finder, notes], hit: 6602).target ==
                  .window(id: 6604, ownerPID: 628))
        try check("native desktop hit over empty desktop keeps screen", try decide([dock, desktop], hit: 27).target == .screen(id: 1))

        let left = CaptureDisplay(id: 2, bounds: CGRect(x: -1280, y: 0, width: 1280, height: 1024))
        let leftDock = CaptureWindow(id: 200, ownerPID: 625, bounds: left.bounds, layer: 20, alpha: 1, isDesktopElement: true)
        let leftFinder = CaptureWindow(id: 201, ownerPID: 628, bounds: left.bounds.insetBy(dx: 100, dy: 100), layer: 0, alpha: 1)
        try check("negative-display coordinates select native Finder", try decide([leftDock, leftFinder], hit: 201,
            at: CGPoint(x: -500, y: 300), displays: [display, left]).target == .window(id: 201, ownerPID: 628))
        try check("negative-display Dock hit falls back to that display", try decide([leftDock, leftFinder], hit: 200,
            at: CGPoint(x: -500, y: 300), displays: [display, left]).target == .screen(id: 2))

        func map(_ point: CGPoint, cg: CGRect? = nil, appKit: CGRect? = nil) -> CGPoint? {
            WindowHitTest.appKitPoint(from: point, primaryDisplayBounds: cg ?? display.bounds,
                                     primaryScreenFrame: appKit ?? display.bounds)
        }
        for (name, input, expected) in [
            ("primary top left", CGPoint.zero, CGPoint(x: 0, y: 900)),
            ("primary interior", point, CGPoint(x: point.x, y: 900 - point.y)),
            ("left display", CGPoint(x: -500, y: 300), CGPoint(x: -500, y: 600)),
            ("display above", CGPoint(x: 200, y: -100), CGPoint(x: 200, y: 1000)),
            ("display below", CGPoint(x: 200, y: 1200), CGPoint(x: 200, y: -300))
        ] { try check("coordinate mapping \(name)", map(input) == expected) }
        try check("nonzero reference origins translate", map(CGPoint(x: 150, y: 250),
            cg: CGRect(x: 100, y: 200, width: 1440, height: 900),
            appKit: CGRect(x: -100, y: 50, width: 1440, height: 900)) == CGPoint(x: -50, y: 900))
        for invalid in [CGPoint(x: CGFloat.nan, y: 0), CGPoint(x: 0, y: CGFloat.infinity)] {
            try check("nonfinite point rejected", map(invalid) == nil)
        }
        for invalid in [CGRect.zero, CGRect(x: 0, y: 0, width: -1, height: 900),
                        CGRect(x: CGFloat.infinity, y: 0, width: 1440, height: 900),
                        CGRect(x: 0, y: 0, width: 1440, height: CGFloat.nan),
                        CGRect(x: CGFloat.greatestFiniteMagnitude, y: 0, width: CGFloat.greatestFiniteMagnitude, height: 900)] {
            try check("invalid primary display geometry rejected", map(point, cg: invalid) == nil)
            try check("invalid AppKit screen geometry rejected", map(point, appKit: invalid) == nil)
        }
        try check("dimension mismatch is rejected rather than pixel-scaled",
                  map(point, appKit: CGRect(x: 0, y: 0, width: 2880, height: 1800)) == nil)
        print("Tahoe Dock tests: \(checks) passed, 0 failed")
    }
}

private struct TestFailure: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}
