import CoreGraphics

struct CaptureWindow: Equatable {
    let id: CGWindowID
    let ownerPID: Int32
    let bounds: CGRect
    let layer: Int
    let alpha: Double
    var isDesktopElement = false
    var sharingState: Int? = nil
    var hasTitle = false
}

struct CaptureDisplay: Equatable {
    let id: CGDirectDisplayID
    let bounds: CGRect
}

enum CaptureTarget: Equatable {
    case window(id: CGWindowID, ownerPID: Int32)
    case screen(id: CGDirectDisplayID)
}

enum CaptureSelectionError: Error, Equatable {
    case invalidPointer
    case invalidWindow
    case noDisplay
}

enum CaptureSelectionReason: String {
    case window, desktopElement, ownWindow, unsupportedLayer, noWindow
}

enum CaptureSelectionSource: String {
    case nativeHit, windowList
}

struct CaptureDecision: Equatable {
    let target: CaptureTarget
    let reason: CaptureSelectionReason
    let windowIndex: Int?
    let bypassedWindowIDs: [CGWindowID]
    let source: CaptureSelectionSource
}

enum CaptureSelection {
    // The validated native mouse target is authoritative. Rectangle order is a
    // conservative fallback when the native result cannot be matched safely.
    static func target(at point: CGPoint, windows: [CaptureWindow],
                       displays: [CaptureDisplay], ownPID: Int32,
                       nativeWindowNumber: Int? = nil) throws -> CaptureTarget {
        try decision(at: point, windows: windows, displays: displays, ownPID: ownPID,
                     nativeWindowNumber: nativeWindowNumber).target
    }

    static func decision(at point: CGPoint, windows: [CaptureWindow],
                         displays: [CaptureDisplay], ownPID: Int32,
                         nativeWindowNumber: Int? = nil) throws -> CaptureDecision {
        guard point.x.isFinite, point.y.isFinite else {
            throw CaptureSelectionError.invalidPointer
        }
        if let index = WindowHitTest.matchedIndex(for: nativeWindowNumber, at: point, windows: windows) {
            let bypassed = windows[..<index].filter {
                $0.layer >= 0 && $0.alpha.isFinite && $0.alpha > 0 && valid($0.bounds) && contains($0.bounds, point)
            }.map(\.id)
            return try classify(windows[index], at: point, index: index, displays: displays, ownPID: ownPID,
                                bypassed: bypassed, source: .nativeHit)
        }
        for (index, window) in windows.enumerated() {
            guard window.alpha.isFinite, valid(window.bounds) else {
                throw CaptureSelectionError.invalidWindow
            }
            guard window.layer >= 0, window.alpha > 0,
                  contains(window.bounds, point) else { continue }
            return try classify(window, at: point, index: index, displays: displays, ownPID: ownPID,
                                bypassed: [], source: .windowList)
        }
        return CaptureDecision(target: try screen(at: point, displays: displays), reason: .noWindow,
                               windowIndex: nil, bypassedWindowIDs: [], source: .windowList)
    }

    private static func classify(_ window: CaptureWindow, at point: CGPoint, index: Int,
                                 displays: [CaptureDisplay], ownPID: Int32,
                                 bypassed: [CGWindowID], source: CaptureSelectionSource) throws -> CaptureDecision {
        let reason: CaptureSelectionReason
        if window.isDesktopElement || window.layer < 0 {
            reason = .desktopElement
        } else if window.ownerPID == ownPID {
            reason = .ownWindow
        } else if ![0, 3, 8].contains(window.layer) {
            reason = .unsupportedLayer
        } else {
            guard window.id != 0, window.ownerPID > 0 else { throw CaptureSelectionError.invalidWindow }
            return CaptureDecision(target: .window(id: window.id, ownerPID: window.ownerPID), reason: .window,
                                   windowIndex: index, bypassedWindowIDs: bypassed, source: source)
        }
        return CaptureDecision(target: try screen(at: point, displays: displays), reason: reason,
                               windowIndex: index, bypassedWindowIDs: bypassed, source: source)
    }

    private static func screen(at point: CGPoint, displays: [CaptureDisplay]) throws -> CaptureTarget {
        guard let display = displays.first(where: {
            $0.id != 0 && valid($0.bounds) && contains($0.bounds, point)
        }) else { throw CaptureSelectionError.noDisplay }
        return .screen(id: display.id)
    }

    private static func valid(_ rect: CGRect) -> Bool {
        rect.origin.x.isFinite && rect.origin.y.isFinite &&
            rect.size.width.isFinite && rect.size.height.isFinite &&
            rect.size.width >= 0 && rect.size.height >= 0
    }

    // Half-open edges make adjacent displays unambiguous, including arrangements
    // to the left of or above the main display. All coordinates are CoreGraphics.
    private static func contains(_ rect: CGRect, _ point: CGPoint) -> Bool {
        point.x >= rect.minX && point.x < rect.maxX &&
            point.y >= rect.minY && point.y < rect.maxY
    }
}
