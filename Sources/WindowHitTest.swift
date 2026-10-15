import CoreGraphics

struct CaptureWindowHit {
    let number: Int?
    let appKitPoint: CGPoint?
}

enum WindowHitTest {
    // Both APIs use logical points. AppKit's origin is at the primary screen's
    // bottom left; Quartz's is at its top left, including secondary displays.
    static func appKitPoint(from point: CGPoint, primaryDisplayBounds: CGRect,
                            primaryScreenFrame: CGRect) -> CGPoint? {
        guard point.x.isFinite, point.y.isFinite,
              valid(primaryDisplayBounds), valid(primaryScreenFrame),
              primaryDisplayBounds.size == primaryScreenFrame.size else { return nil }
        let converted = CGPoint(x: primaryScreenFrame.minX + point.x - primaryDisplayBounds.minX,
                                y: primaryScreenFrame.maxY - (point.y - primaryDisplayBounds.minY))
        return converted.x.isFinite && converted.y.isFinite ? converted : nil
    }

    static func matchedIndex(for number: Int?, at point: CGPoint,
                             windows: [CaptureWindow]) -> Int? {
        guard let number, number > 0, let id = CGWindowID(exactly: number),
              point.x.isFinite, point.y.isFinite else { return nil }
        let matches = windows.indices.filter { windows[$0].id == id }
        guard matches.count == 1, let index = matches.first else { return nil }
        let window = windows[index]
        guard window.ownerPID > 0, window.alpha.isFinite, window.alpha > 0,
              valid(window.bounds), point.x >= window.bounds.minX, point.x < window.bounds.maxX,
              point.y >= window.bounds.minY, point.y < window.bounds.maxY else { return nil }
        return index
    }

    private static func valid(_ rect: CGRect) -> Bool {
        rect.origin.x.isFinite && rect.origin.y.isFinite &&
            rect.size.width.isFinite && rect.size.height.isFinite &&
            rect.size.width > 0 && rect.size.height > 0 &&
            rect.maxX.isFinite && rect.maxY.isFinite
    }
}
