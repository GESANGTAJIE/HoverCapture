import CoreGraphics
import Foundation

@main
struct SelectionTests {
    static func main() throws {
        let main = CaptureDisplay(id: 1, bounds: CGRect(x: 0, y: 0, width: 1440, height: 900))
        let left = CaptureDisplay(id: 2, bounds: CGRect(x: -1280, y: 0, width: 1280, height: 1024))
        let above = CaptureDisplay(id: 3, bounds: CGRect(x: 0, y: -1080, width: 1920, height: 1080))
        let displays = [main, left, above]
        var checks = 0
        func window(_ id: UInt32, x: CGFloat = 100, y: CGFloat = 100, layer: Int = 0,
                    alpha: Double = 1, pid: Int32 = 42, desktop: Bool = false) -> CaptureWindow {
            CaptureWindow(id: id, ownerPID: pid, bounds: CGRect(x: x, y: y, width: 500, height: 400),
                          layer: layer, alpha: alpha, isDesktopElement: desktop)
        }
        func expect(_ name: String, _ windows: [CaptureWindow], _ expected: CaptureTarget,
                    at point: CGPoint = CGPoint(x: 150, y: 150)) throws {
            let actual = try CaptureSelection.target(at: point, windows: windows, displays: displays, ownPID: 99)
            guard actual == expected else {
                throw TestFailure(message: "\(name): expected \(expected), got \(actual)")
            }
            checks += 1
        }
        func expectFailure(_ name: String, _ windows: [CaptureWindow], _ expected: CaptureSelectionError,
                           at point: CGPoint = CGPoint(x: 150, y: 150)) throws {
            do {
                _ = try CaptureSelection.target(at: point, windows: windows, displays: displays, ownPID: 99)
                throw TestFailure(message: "\(name): selection unexpectedly succeeded")
            } catch let error as CaptureSelectionError {
                guard error == expected else { throw TestFailure(message: "\(name): wrong failure \(error)") }
                checks += 1
            }
        }

        try expect("frontmost window wins", [window(11), window(12)], .window(id: 11, ownerPID: 42))
        try expect("exposed portion selects back window", [window(11, x: 300), window(12)], .window(id: 12, ownerPID: 42))
        try expect("floating panel", [window(11, layer: 3), window(12)], .window(id: 11, ownerPID: 42))
        try expect("modal panel", [window(11, layer: 8), window(12)], .window(id: 11, ownerPID: 42))
        try expect("menu blocks window behind it", [window(11, layer: 101), window(12)], .screen(id: 1))
        try expect("Dock blocks window behind it", [window(11, layer: 20), window(12)], .screen(id: 1))
        try expect("Dock at normal layer is desktop", [window(11, desktop: true), window(12)], .screen(id: 1))
        try expect("own Settings does not expose back window", [window(11, pid: 99), window(12)], .screen(id: 1))
        try expect("transparent surface is ignored", [window(11, alpha: 0), window(12)], .window(id: 12, ownerPID: 42))
        try expect("partly transparent surface still wins", [window(11, alpha: 0.05), window(12)], .window(id: 11, ownerPID: 42))
        try expect("desktop layer ignored", [window(11, layer: -1)], .screen(id: 1))
        try expect("empty desktop", [], .screen(id: 1))
        try expect("negative X display", [], .screen(id: 2), at: CGPoint(x: -300, y: 500))
        try expect("negative Y display", [], .screen(id: 3), at: CGPoint(x: 500, y: -300))
        try expect("display boundary chooses right", [], .screen(id: 1), at: CGPoint(x: 0, y: 500))
        try expect("display boundary chooses below", [], .screen(id: 1), at: CGPoint(x: 500, y: 0))
        try expect("window left edge included", [window(11)], .window(id: 11, ownerPID: 42), at: CGPoint(x: 100, y: 150))
        try expect("window right edge excluded", [window(11)], .screen(id: 1), at: CGPoint(x: 600, y: 150))
        try expect("window bottom edge excluded", [window(11)], .screen(id: 1), at: CGPoint(x: 150, y: 500))
        try expect("window on left display", [window(11, x: -600)], .window(id: 11, ownerPID: 42), at: CGPoint(x: -500, y: 150))
        try expect("window on upper display", [window(11, y: -500)], .window(id: 11, ownerPID: 42), at: CGPoint(x: 150, y: -300))
        try expectFailure("invalid ID never captures screen", [window(0)], .invalidWindow)
        try expectFailure("invalid owner never captures screen", [window(11, pid: 0)], .invalidWindow)
        try expectFailure("invalid pointer", [], .invalidPointer, at: CGPoint(x: CGFloat.nan, y: 100))
        try expectFailure("pointer outside all displays", [], .noDisplay, at: CGPoint(x: 9999, y: 9999))
        try expectFailure("invalid alpha", [window(11, alpha: .nan)], .invalidWindow)
        try expectFailure("invalid bounds", [window(11, x: .infinity)], .invalidWindow)
        print("Selection tests: \(checks) passed, 0 failed")
    }
}

private struct TestFailure: Error {
    let message: String
}
