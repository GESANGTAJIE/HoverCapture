import CoreGraphics
import Foundation

@main
struct TahoeDockTests {
    static func main() async throws {
        // Actual RC2 diagnosis from the affected M1 / Tahoe 26.1 machine.
        let display = CaptureDisplay(id: 1, bounds: CGRect(x: 0, y: 0, width: 1440, height: 900))
        let point = CGPoint(x: 691.4140625, y: 242.34765625)
        let dock = CaptureWindow(id: 16, ownerPID: 625, bounds: display.bounds,
                                 layer: 20, alpha: 1, isDesktopElement: true,
                                 sharingState: 1, hasTitle: true)
        let finder = CaptureWindow(id: 5206, ownerPID: 628,
                                   bounds: CGRect(x: 219, y: 213, width: 920, height: 436),
                                   layer: 0, alpha: 1, sharingState: 1, hasTitle: true)
        let settings = CaptureWindow(id: 5203, ownerPID: 6555,
                                     bounds: CGRect(x: 320, y: 31, width: 723, height: 792),
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
        func resolve(_ windows: [CaptureWindow], at location: CGPoint? = nil,
                     alpha: DockAlphaResult = .transparent) async throws -> CaptureResolution {
            try await CaptureResolver.resolve(at: location ?? point, windows: windows, displays: [display], ownPID: 6552) { _ in
                await Task.yield()
                return DockProbeResult(alpha: alpha, detail: "testProbe")
            }
        }
        for (name, windows) in [
            ("actual reported window order", [dock, finder, settings, desktop, dockDesktop, wallpaper, background]),
            ("minimal Dock and Finder reproduction", [dock, finder])
        ] {
            let actual = try await resolve(windows)
            try check(name, actual.decision.target == .window(id: 5206, ownerPID: 628))
            try check("\(name) records transparent Dock", actual.decision.skippedDockWindowIDs == [16] &&
                      actual.dockProbes[16]?.alpha == .transparent)
        }
        let withoutProof = try CaptureSelection.target(at: point, windows: [dock, finder], displays: [display], ownPID: 6552)
        try check("metadata alone never authorizes skip", withoutProof == .screen(id: 1))
        for alpha in [DockAlphaResult.visible, .unavailable] {
            let actual = try await resolve([dock, finder], alpha: alpha)
            try check("\(alpha) keeps screen fallback", actual.decision.target == .screen(id: 1) &&
                      actual.decision.reason == .desktopElement && actual.decision.skippedDockWindowIDs.isEmpty)
            try check("\(alpha) remains visible in diagnosis", actual.dockProbes[16]?.alpha == alpha)
        }
        for state: Int? in [nil, 0, 1, 2] {
            for title in [false, true] {
                var variant = dock
                variant.sharingState = state
                variant.hasTitle = title
                let actual = try await resolve([variant, finder])
                try check("sharing \(String(describing: state)), title \(title) use pixel proof",
                          actual.decision.target == .window(id: 5206, ownerPID: 628))
            }
        }
        let desktopResult = try await resolve([dock, desktop, dockDesktop, wallpaper, background])
        try check("transparent Dock over desktop remains screen", desktopResult.decision.target == .screen(id: 1) &&
                  desktopResult.decision.reason == .noWindow)
        let frontMenu = CaptureWindow(id: 100, ownerPID: 628, bounds: finder.bounds, layer: 101, alpha: 1)
        let frontResult = try await resolve([frontMenu, dock, finder])
        try check("front menu blocks before any probe", frontResult.decision.target == .screen(id: 1) && frontResult.dockProbes.isEmpty)
        let backResult = try await resolve([dock, frontMenu, finder])
        try check("menu behind transparent Dock still blocks", backResult.decision.target == .screen(id: 1) &&
                  backResult.decision.windowIndex == 1 && backResult.decision.skippedDockWindowIDs == [16])
        let popup = CaptureWindow(id: 101, ownerPID: 628, bounds: finder.bounds, layer: 8, alpha: 1)
        let popupResult = try await resolve([popup, dock, finder])
        try check("popup ahead of Dock needs no probe", popupResult.decision.target == .window(id: 101, ownerPID: 628) &&
                  popupResult.dockProbes.isEmpty)
        for (name, blocker) in [
            ("other owner", CaptureWindow(id: 102, ownerPID: 700, bounds: display.bounds, layer: 20, alpha: 1)),
            ("Mission Control", CaptureWindow(id: 103, ownerPID: 625, bounds: display.bounds, layer: 18, alpha: 1, isDesktopElement: true)),
            ("partial Dock", CaptureWindow(id: 104, ownerPID: 625, bounds: finder.bounds, layer: 20, alpha: 1, isDesktopElement: true))
        ] {
            let actual = try await resolve([blocker, finder])
            try check("\(name) never probes", actual.decision.target == .screen(id: 1) && actual.dockProbes.isEmpty)
        }
        let bottomWindow = CaptureWindow(id: 105, ownerPID: 628, bounds: display.bounds, layer: 0, alpha: 1)
        let dockIconResult = try await resolve([dock, bottomWindow], at: CGPoint(x: 700, y: 870), alpha: .visible)
        try check("visible Dock pixels do not expose app behind", dockIconResult.decision.target == .screen(id: 1))
        // Compose the actual alpha sampler and resolver using a generated Dock
        // surface with transparent space above its visible bottom row.
        var pixels = [UInt8](repeating: 0, count: 8 * 5 * 4)
        for x in 0..<8 { pixels[(4 * 8 + x) * 4 + 3] = 255 }
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        let dockImage = CGImage(width: 8, height: 5, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 32,
                               space: CGColorSpaceCreateDeviceRGB(),
                               bitmapInfo: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Big.rawValue |
                                                       CGImageAlphaInfo.premultipliedLast.rawValue),
                               provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        for (name, location, expected) in [
            ("sampled transparent Finder position", point, CaptureTarget.window(id: 5206, ownerPID: 628)),
            ("sampled visible Dock position", CGPoint(x: 700, y: 870), CaptureTarget.screen(id: 1))
        ] {
            let actual = try await CaptureResolver.resolve(at: location, windows: [dock, finder, bottomWindow],
                                                          displays: [display], ownPID: 6552) { window in
                DockProbeResult(alpha: DockAlpha.sample(dockImage, at: location, in: window.bounds), detail: "sampled")
            }
            try check(name, actual.decision.target == expected)
        }
        let secondDock = CaptureWindow(id: 106, ownerPID: 625, bounds: display.bounds, layer: 20, alpha: 1, isDesktopElement: true)
        var probed: [CGWindowID] = []
        let twoDockResult = try await CaptureResolver.resolve(at: point, windows: [dock, secondDock, finder],
                                                              displays: [display], ownPID: 6552) { window in
            probed.append(window.id)
            return DockProbeResult(alpha: window.id == 16 ? .transparent : .visible, detail: "testProbe")
        }
        try check("multiple Dock surfaces resolved in original order", probed == [16, 106] &&
                  twoDockResult.decision.target == .screen(id: 1) && twoDockResult.decision.windowIndex == 1)
        let duplicateResult = try await resolve([dock, dock, finder])
        try check("duplicate ID cannot cause repeated probe loop", duplicateResult.dockProbes.count == 1 &&
                  duplicateResult.decision.target == .window(id: 5206, ownerPID: 628))
        var movingPoint = point
        var changingWindows = [dock, finder]
        let frozenResult = try await CaptureResolver.resolve(at: movingPoint, windows: changingWindows,
                                                             displays: [display], ownPID: 6552) { _ in
            movingPoint = CGPoint(x: 0, y: 0)
            changingWindows.removeAll()
            await Task.yield()
            return DockProbeResult(alpha: .transparent, detail: "testProbe")
        }
        try check("await does not retarget after pointer/list changes", frozenResult.decision.target == .window(id: 5206, ownerPID: 628))
        print("Tahoe Dock tests: \(checks) passed, 0 failed")
    }
}

private struct TestFailure: Error {
    let message: String
}
