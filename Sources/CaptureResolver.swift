import CoreGraphics

struct DockProbeResult: Equatable {
    let alpha: DockAlphaResult
    let detail: String
}

struct CaptureResolution {
    let decision: CaptureDecision
    let dockProbes: [CGWindowID: DockProbeResult]
}

enum CaptureResolver {
    // Only inspect a Dock surface that actually blocks the frozen pointer. Never
    // probe windows behind a visible blocker or re-read pointer/window ordering.
    static func resolve(at point: CGPoint, windows: [CaptureWindow], displays: [CaptureDisplay],
                        ownPID: Int32,
                        probe: (CaptureWindow) async -> DockProbeResult) async throws -> CaptureResolution {
        var transparentIDs: Set<CGWindowID> = []
        var probes: [CGWindowID: DockProbeResult] = [:]
        var decision = try CaptureSelection.decision(at: point, windows: windows, displays: displays, ownPID: ownPID)
        while decision.reason == .desktopElement, let index = decision.windowIndex {
            let window = windows[index]
            guard CaptureSelection.isFullDisplayDock(window, displays: displays), probes[window.id] == nil else { break }
            let result = await probe(window)
            probes[window.id] = result
            guard result.alpha == .transparent else { break }
            transparentIDs.insert(window.id)
            decision = try CaptureSelection.decision(at: point, windows: windows, displays: displays,
                                                     ownPID: ownPID, transparentDockWindowIDs: transparentIDs)
        }
        return CaptureResolution(decision: decision, dockProbes: probes)
    }
}
