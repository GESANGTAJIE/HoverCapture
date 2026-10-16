import CoreGraphics
import Darwin

@main
struct NativeTargetTests {
    static func main() throws {
        // Actual RC4 report from Tahoe 26.1, including the observed native hit.
        // These are the seven relevant rows, retaining their relative order.
        let display = CaptureDisplay(id: 1, bounds: CGRect(x: 0, y: 0, width: 1440, height: 900))
        let point = CGPoint(x: 817.578125, y: 175.34765625)
        let wps = CaptureWindow(id: 12989, ownerPID: 12181, bounds: display.bounds,
                                layer: 2147483630, alpha: 1, sharingState: 1)
        let dock = CaptureWindow(id: 16, ownerPID: 625, bounds: display.bounds,
                                 layer: 20, alpha: 1, isDesktopElement: true, sharingState: 1, hasTitle: true)
        let finder = CaptureWindow(id: 13596, ownerPID: 628,
                                   bounds: CGRect(x: 332, y: 157, width: 920, height: 436),
                                   layer: 0, alpha: 1, sharingState: 1, hasTitle: true)
        let desktop = CaptureWindow(id: 27, ownerPID: 628, bounds: display.bounds,
                                    layer: -2147483603, alpha: 1, sharingState: 1)
        let dockDesktop = CaptureWindow(id: 17, ownerPID: 625, bounds: display.bounds,
                                        layer: -2147483624, alpha: 1, isDesktopElement: true,
                                        sharingState: 1, hasTitle: true)
        let wallpaper = CaptureWindow(id: 1251, ownerPID: 645, bounds: display.bounds,
                                      layer: -2147483625, alpha: 1, sharingState: 1, hasTitle: true)
        let background = CaptureWindow(id: 2, ownerPID: 404, bounds: display.bounds,
                                       layer: -2147483626, alpha: 1, sharingState: 1)
        var passed = 0
        var failed = 0
        for (name, windows) in [
            ("actual WPS + Dock + Finder report", [wps, dock, finder, desktop, dockDesktop, wallpaper, background]),
            ("minimal WPS + Finder report", [wps, finder])
        ] {
            let actual = try CaptureSelection.target(at: point, windows: windows, displays: [display],
                                                      ownPID: 20015, nativeWindowNumber: 13596)
            if actual == .window(id: 13596, ownerPID: 628) {
                passed += 1
            } else {
                failed += 1
                print("FAIL \(name): native hit Finder 13596, selected \(actual)")
            }
        }
        print("Native target regressions: \(passed) passed, \(failed) failed")
        if failed > 0 { exit(1) }
    }
}
