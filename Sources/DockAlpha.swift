import CoreGraphics

enum DockAlphaResult: String {
    case transparent, visible, unavailable
}

enum DockAlpha {
    static func sample(_ image: CGImage, at point: CGPoint, in bounds: CGRect) -> DockAlphaResult {
        guard bounds.origin.x.isFinite, bounds.origin.y.isFinite,
              bounds.size.width.isFinite, bounds.size.height.isFinite,
              bounds.size.width > 0, bounds.size.height > 0,
              bounds.maxX.isFinite, bounds.maxY.isFinite,
              point.x.isFinite, point.y.isFinite,
              point.x >= bounds.minX, point.x < bounds.maxX,
              point.y >= bounds.minY, point.y < bounds.maxY,
              image.width > 0, image.height > 0,
              image.bitsPerComponent == 8, image.bitsPerPixel == 32 else { return .unavailable }
        switch image.alphaInfo {
        case .premultipliedFirst, .premultipliedLast, .first, .last:
            break
        default:
            // Flattened or unsupported images cannot prove the surface was clear.
            return .unavailable
        }

        // CGWindow bounds and the image's raster use top-left coordinates.
        // Actual image dimensions also cover Retina and scaled output sizes.
        let mappedX = floor((point.x - bounds.minX) / bounds.width * CGFloat(image.width))
        let mappedY = floor((point.y - bounds.minY) / bounds.height * CGFloat(image.height))
        guard let rawX = Int(exactly: mappedX), let rawY = Int(exactly: mappedY) else {
            return .unavailable
        }
        let x = min(rawX, image.width - 1)
        let y = min(rawY, image.height - 1)
        let left = max(0, x - 1)
        let top = max(0, y - 1)
        let width = min(image.width - 1, x + 1) - left + 1
        let height = min(image.height - 1, y + 1) - top + 1
        guard let crop = image.cropping(to: CGRect(x: left, y: top, width: width, height: height)),
              crop.width == width, crop.height == height else { return .unavailable }

        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        let rendered = rgba.withUnsafeMutableBytes { bytes -> Bool in
            let format = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
            guard let context = CGContext(data: bytes.baseAddress, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: width * 4,
                                          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: format) else {
                return false
            }
            context.setBlendMode(.copy)
            context.interpolationQuality = .none
            context.draw(crop, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard rendered else { return .unavailable }
        // Any visible neighboring pixel blocks the window behind the Dock.
        for alpha in stride(from: 3, to: rgba.count, by: 4) where rgba[alpha] != 0 {
            return .visible
        }
        return .transparent
    }
}
