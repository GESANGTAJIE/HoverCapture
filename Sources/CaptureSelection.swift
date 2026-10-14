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

enum CaptureSelection {
    // WindowServer supplies these windows from front to back. Stop at the first
    // visible surface: a menu must not expose a window behind it as the target.
    static func target(at point: CGPoint, windows: [CaptureWindow],
                       displays: [CaptureDisplay], ownPID: Int32) throws -> CaptureTarget {
        guard point.x.isFinite, point.y.isFinite else {
            throw CaptureSelectionError.invalidPointer
        }
        for window in windows {
            guard window.alpha.isFinite, valid(window.bounds) else {
                throw CaptureSelectionError.invalidWindow
            }
            guard window.layer >= 0, window.alpha > 0,
                  contains(window.bounds, point) else { continue }
            // Tahoe's visible Dock can add an invisible full-display tracking
            // surface. Match its complete signature, not all Dock/overlay windows;
            // the visible Dock strip and menus must still block windows behind them.
            if window.isDesktopElement, window.layer == 20, window.sharingState == 0,
               !window.hasTitle,
               displays.contains(where: { $0.id != 0 && $0.bounds == window.bounds }) {
                continue
            }
            if window.isDesktopElement || window.ownerPID == ownPID ||
                ![0, 3, 8].contains(window.layer) {
                return try screen(at: point, displays: displays)
            }
            guard window.id != 0, window.ownerPID > 0 else {
                throw CaptureSelectionError.invalidWindow
            }
            return .window(id: window.id, ownerPID: window.ownerPID)
        }
        return try screen(at: point, displays: displays)
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
