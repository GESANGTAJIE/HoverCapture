import CoreGraphics
import Foundation

@main
struct DockAlphaTests {
    static func main() throws {
        var checks = 0
        func check(_ name: String, _ actual: DockAlphaResult, _ expected: DockAlphaResult) throws {
            guard actual == expected else {
                throw TestFailure(message: "\(name): expected \(expected), got \(actual)")
            }
            checks += 1
        }
        func image(width: Int = 7, height: Int = 7, alpha: UInt8 = 0,
                   pixels: [(Int, Int, UInt8)] = [],
                   alphaInfo: CGImageAlphaInfo = .premultipliedLast) throws -> CGImage {
            let alphaFirst = alphaInfo == .premultipliedFirst || alphaInfo == .first || alphaInfo == .noneSkipFirst
            let alphaOffset = alphaFirst ? 0 : 3
            var bytes = [UInt8](repeating: 0, count: width * height * 4)
            for offset in stride(from: alphaOffset, to: bytes.count, by: 4) { bytes[offset] = alpha }
            for (x, y, value) in pixels { bytes[(y * width + x) * 4 + alphaOffset] = value }
            guard let provider = CGDataProvider(data: Data(bytes) as CFData),
                  let result = CGImage(width: width, height: height, bitsPerComponent: 8,
                                       bitsPerPixel: 32, bytesPerRow: width * 4,
                                       space: CGColorSpaceCreateDeviceRGB(),
                                       bitmapInfo: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Big.rawValue | alphaInfo.rawValue),
                                       provider: provider, decode: nil, shouldInterpolate: false,
                                       intent: .defaultIntent) else {
                throw TestFailure(message: "could not create test image")
            }
            return result
        }
        let bounds = CGRect(x: 0, y: 0, width: 7, height: 7)
        let center = CGPoint(x: 3.5, y: 3.5)
        let clear = try image()
        try check("fully transparent", DockAlpha.sample(clear, at: center, in: bounds), .transparent)
        try check("fully opaque", DockAlpha.sample(try image(alpha: 255), at: center, in: bounds), .visible)
        try check("semitransparent", DockAlpha.sample(try image(alpha: 128), at: center, in: bounds), .visible)
        try check("lowest nonzero alpha blocks", DockAlpha.sample(try image(alpha: 1), at: center, in: bounds), .visible)
        try check("neighbor blocks", DockAlpha.sample(try image(pixels: [(2, 2, 255)]), at: center, in: bounds), .visible)
        try check("outside neighborhood does not block", DockAlpha.sample(try image(pixels: [(1, 1, 255)]), at: center, in: bounds), .transparent)

        let topPixel = try image(pixels: [(3, 0, 255)])
        let bottomPixel = try image(pixels: [(3, 6, 255)])
        try check("top raster row at top pointer", DockAlpha.sample(topPixel, at: CGPoint(x: 3.5, y: 0.5), in: bounds), .visible)
        try check("top raster row not bottom pointer", DockAlpha.sample(topPixel, at: CGPoint(x: 3.5, y: 6.5), in: bounds), .transparent)
        try check("bottom raster row at bottom pointer", DockAlpha.sample(bottomPixel, at: CGPoint(x: 3.5, y: 6.5), in: bounds), .visible)
        try check("bottom raster row not top pointer", DockAlpha.sample(bottomPixel, at: CGPoint(x: 3.5, y: 0.5), in: bounds), .transparent)
        try check("Retina coordinate mapping", DockAlpha.sample(try image(width: 14, height: 14, pixels: [(6, 2, 255)]),
                                                               at: CGPoint(x: 3.1, y: 1.1), in: bounds), .visible)
        try check("Retina mapping does not use unscaled point", DockAlpha.sample(try image(width: 14, height: 14, pixels: [(3, 1, 255)]),
                                                                                at: CGPoint(x: 3.1, y: 1.1), in: bounds), .transparent)
        let negative = CGRect(x: -200, y: -100, width: 7, height: 7)
        try check("negative display origin", DockAlpha.sample(topPixel, at: CGPoint(x: -196.5, y: -99.5), in: negative), .visible)
        let scaled = CGRect(x: 10, y: 20, width: 14, height: 21)
        try check("nonuniform output scale", DockAlpha.sample(topPixel, at: CGPoint(x: 17, y: 20.1), in: scaled), .visible)

        try check("top left border clamps neighborhood", DockAlpha.sample(try image(pixels: [(0, 0, 255)]), at: .zero, in: bounds), .visible)
        try check("bottom right border clamps neighborhood", DockAlpha.sample(try image(pixels: [(6, 6, 255)]),
                                                                             at: CGPoint(x: 6.999, y: 6.999), in: bounds), .visible)
        try check("single transparent pixel image", DockAlpha.sample(try image(width: 1, height: 1), at: center, in: bounds), .transparent)
        try check("single opaque pixel image", DockAlpha.sample(try image(width: 1, height: 1, alpha: 255), at: center, in: bounds), .visible)
        try check("first alpha layout", DockAlpha.sample(try image(alpha: 255, alphaInfo: .premultipliedFirst), at: center, in: bounds), .visible)
        try check("first alpha clear layout", DockAlpha.sample(try image(alphaInfo: .premultipliedFirst), at: center, in: bounds), .transparent)
        try check("unpremultiplied last layout", DockAlpha.sample(try image(alpha: 1, alphaInfo: .last), at: center, in: bounds), .visible)
        try check("unpremultiplied first layout", DockAlpha.sample(try image(alpha: 1, alphaInfo: .first), at: center, in: bounds), .visible)
        try check("skip last format is not transparency evidence", DockAlpha.sample(try image(alphaInfo: .noneSkipLast), at: center, in: bounds), .unavailable)
        try check("skip first format is not transparency evidence", DockAlpha.sample(try image(alphaInfo: .noneSkipFirst), at: center, in: bounds), .unavailable)
        let rgbData = Data(repeating: 0, count: 7 * 7 * 3)
        guard let rgbProvider = CGDataProvider(data: rgbData as CFData),
              let rgb = CGImage(width: 7, height: 7, bitsPerComponent: 8, bitsPerPixel: 24, bytesPerRow: 21,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: 0),
                                provider: rgbProvider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
            throw TestFailure(message: "could not create RGB test image")
        }
        try check("no alpha format is unavailable", DockAlpha.sample(rgb, at: center, in: bounds), .unavailable)
        for alpha: UInt8 in [0, 1, 255] {
            let bgraData = Data([0, 0, 0, alpha])
            guard let provider = CGDataProvider(data: bgraData as CFData),
                  let bgra = CGImage(width: 1, height: 1, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 4,
                                     space: CGColorSpaceCreateDeviceRGB(),
                                     bitmapInfo: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue),
                                     provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else {
                throw TestFailure(message: "could not create BGRA test image")
            }
            try check("BGRA alpha \(alpha)", DockAlpha.sample(bgra, at: center, in: bounds), alpha == 0 ? .transparent : .visible)
        }
        try check("negative width does not standardize", DockAlpha.sample(clear, at: CGPoint(x: -3.5, y: 3.5),
                                                                         in: CGRect(x: 0, y: 0, width: -7, height: 7)), .unavailable)
        try check("negative height does not standardize", DockAlpha.sample(clear, at: CGPoint(x: 3.5, y: -3.5),
                                                                          in: CGRect(x: 0, y: 0, width: 7, height: -7)), .unavailable)

        for (name, point) in [("right half-open edge", CGPoint(x: 7, y: 3)),
                              ("bottom half-open edge", CGPoint(x: 3, y: 7)),
                              ("left outside", CGPoint(x: -0.01, y: 3)),
                              ("top outside", CGPoint(x: 3, y: -0.01)),
                              ("NaN pointer", CGPoint(x: CGFloat.nan, y: 3)),
                              ("infinite pointer", CGPoint(x: 3, y: CGFloat.infinity))] {
            try check(name, DockAlpha.sample(clear, at: point, in: bounds), .unavailable)
        }
        for (name, invalid) in [("zero width", CGRect(x: 0, y: 0, width: 0, height: 7)),
                                ("zero height", CGRect(x: 0, y: 0, width: 7, height: 0)),
                                ("negative width", CGRect(x: 0, y: 0, width: -7, height: 7)),
                                ("NaN origin", CGRect(x: CGFloat.nan, y: 0, width: 7, height: 7)),
                                ("infinite height", CGRect(x: 0, y: 0, width: 7, height: CGFloat.infinity)),
                                ("overflowing bounds", CGRect(x: CGFloat.greatestFiniteMagnitude, y: 0,
                                                             width: CGFloat.greatestFiniteMagnitude, height: 7))] {
            try check(name, DockAlpha.sample(clear, at: center, in: invalid), .unavailable)
        }
        print("\(checks) Dock alpha checks passed")
    }
}

private struct TestFailure: Error {
    let message: String
}
