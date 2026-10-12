import AppKit

@main
struct BatchTests {
    @MainActor
    static func main() throws {
        var checks = 0
        func expect(_ name: String, _ condition: @autoclosure () -> Bool) throws {
            guard condition() else { throw TestFailure(message: name) }
            checks += 1
        }
        func data(_ number: UInt8) -> Data { Data([number]) }

        let clipboard = FakePasteboard()
        let batch = CaptureBatch(pasteboard: clipboard)
        try expect("default capacity is one", batch.capacity == 1)
        try expect("empty copy fails without changing clipboard", !batch.copyAll() && !batch.copyLatest() && clipboard.changeCount == 0)
        try expect("first capture copies", batch.append(pngData: data(1), fileURL: nil))
        try expect("second capture replaces default single image", batch.append(pngData: data(2), fileURL: nil) && batch.count == 1 && clipboard.ids == [2])
        try expect("capacity below range clamps to one", CaptureBatch(capacity: Int.min, pasteboard: clipboard).capacity == 1)
        try expect("capacity above range clamps to twenty", CaptureBatch(capacity: Int.max, pasteboard: clipboard).capacity == 20)

        let beforeGrowth = clipboard.changeCount
        try expect("growing capacity does not republish", batch.setCapacity(3) && clipboard.changeCount == beforeGrowth)
        batch.append(pngData: data(3), fileURL: nil)
        batch.append(pngData: data(4), fileURL: nil)
        batch.append(pngData: data(5), fileURL: nil)
        try expect("keeps latest N in capture order", batch.count == 3 && clipboard.ids == [3, 4, 5])
        try expect("shrink trims oldest and updates our clipboard", batch.setCapacity(2) && batch.count == 2 && clipboard.ids == [4, 5])
        try expect("copy latest preserves batch", batch.copyLatest() && batch.count == 2 && clipboard.ids == [5])
        try expect("copy all restores full batch order", batch.copyAll() && clipboard.ids == [4, 5])

        clipboard.externalCopy()
        let externalChange = clipboard.changeCount
        try expect("shrinking leaves external clipboard untouched", batch.setCapacity(1) && batch.count == 1 && clipboard.changeCount == externalChange && clipboard.hasExternalContent)
        batch.clear()
        try expect("clear empties batch without clearing external clipboard", batch.count == 0 && clipboard.changeCount == externalChange && clipboard.hasExternalContent)
        try expect("explicit capture replaces external clipboard", batch.append(pngData: data(6), fileURL: nil) && clipboard.ids == [6])
        batch.clear()
        try expect("clear clears our clipboard", batch.count == 0 && clipboard.ids.isEmpty && !clipboard.hasExternalContent)

        clipboard.failNextWrite = true
        try expect("copy failure is reported while retaining image", !batch.append(pngData: data(7), fileURL: nil) && batch.count == 1)
        try expect("failed copy can be retried", batch.copyAll() && clipboard.ids == [7])
        batch.setCapacity(2)
        batch.append(pngData: data(8), fileURL: nil)
        clipboard.failNextWrite = true
        try expect("shrink reports write failure and retains remaining image", !batch.setCapacity(1) && batch.count == 1)
        try expect("shrink failure can be retried", batch.copyAll() && clipboard.ids == [8])
        clipboard.externalCopy()
        try expect("explicit copy latest replaces external content", batch.copyLatest() && clipboard.ids == [8])
        batch.setCapacity(999)
        try expect("runtime capacity is clamped", batch.capacity == 20)

        let latestClipboard = FakePasteboard()
        let latestBatch = CaptureBatch(capacity: 3, pasteboard: latestClipboard)
        latestBatch.append(pngData: data(1), fileURL: nil)
        latestBatch.append(pngData: data(2), fileURL: nil)
        latestBatch.append(pngData: data(3), fileURL: nil)
        latestBatch.copyLatest()
        let latestChange = latestClipboard.changeCount
        try expect("shrink preserves explicit latest-only clipboard", latestBatch.setCapacity(2) && latestBatch.count == 2 && latestClipboard.ids == [3] && latestClipboard.changeCount == latestChange)
        try expect("same capacity is a no-op", latestBatch.setCapacity(2) && latestClipboard.changeCount == latestChange)
        try expect("copy all exits latest-only mode", latestBatch.copyAll() && latestClipboard.ids == [2, 3])
        latestBatch.copyLatest()
        try expect("new capture publishes full batch after latest-only copy", latestBatch.append(pngData: data(4), fileURL: nil) && latestClipboard.ids == [3, 4])
        print("Batch model tests: \(checks) passed, 0 failed")

        let privateBoard = NSPasteboard(name: NSPasteboard.Name("HoverCapture.BatchTests.\(UUID().uuidString)"))
        defer { privateBoard.releaseGlobally() }
        privateBoard.clearContents()
        guard privateBoard.setString("availability check", forType: .string),
              privateBoard.string(forType: .string) == "availability check" else {
            let message = "Private macOS pasteboard service is unavailable (basic text write/read failed)."
            if CommandLine.arguments.contains("--require-pasteboard") {
                throw TestFailure(message: message)
            }
            print("Batch pasteboard integration: SKIPPED. \(message) Use --require-pasteboard to require this check.")
            return
        }
        let modelChecks = checks
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("HoverCapture-BatchTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer {
            do { try FileManager.default.removeItem(at: folder) }
            catch { fputs("Batch tests: temporary folder cleanup failed: \(error)\n", stderr) }
        }
        let firstPNG = try png(red: 200)
        let secondPNG = try png(red: 50)
        let firstURL = folder.appendingPathComponent("截图 1.png")
        let secondURL = folder.appendingPathComponent("截图 2.png")
        try firstPNG.write(to: firstURL)
        try secondPNG.write(to: secondURL)
        let realBatch = CaptureBatch(capacity: 3, pasteboard: SystemCapturePasteboard(privateBoard))
        try expect("native first PNG copy", realBatch.append(pngData: firstPNG, fileURL: firstURL))
        try expect("native multiple PNG copy", realBatch.append(pngData: secondPNG, fileURL: secondURL))
        let nativeItems = privateBoard.pasteboardItems ?? []
        try expect("native pasteboard has two distinct items", nativeItems.count == 2)
        try expect("native PNG item order is preserved", nativeItems.map { $0.data(forType: .png) } == [firstPNG, secondPNG])
        try expect("native URL matches PNG in each item", nativeItems.map { $0.string(forType: .fileURL) } == [firstURL.absoluteString, secondURL.absoluteString])
        let fileURLs = privateBoard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]
        try expect("native file readers receive both PNG files in order", fileURLs == [firstURL, secondURL])
        try expect("native image-only item survives save failure", realBatch.append(pngData: firstPNG, fileURL: nil))
        try expect("native image-only item has PNG without URL", privateBoard.pasteboardItems?.last?.data(forType: .png) == firstPNG && privateBoard.pasteboardItems?.last?.string(forType: .fileURL) == nil)
        privateBoard.clearContents()
        privateBoard.setString("external text", forType: .string)
        realBatch.setCapacity(1)
        realBatch.clear()
        try expect("native external text survives capacity change and clear", privateBoard.string(forType: .string) == "external text")
        try expect("clear never deletes saved files", FileManager.default.fileExists(atPath: firstURL.path) && FileManager.default.fileExists(atPath: secondURL.path))
        print("Batch pasteboard integration: \(checks - modelChecks) passed, 0 failed")
    }

    private static func png(red: UInt8) throws -> Data {
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1, pixelsHigh: 1,
                                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                           isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 4, bitsPerPixel: 32),
              let pixel = bitmap.bitmapData else {
            throw TestFailure(message: "Could not create test image")
        }
        pixel[0] = red
        pixel[1] = 0
        pixel[2] = 0
        pixel[3] = 255
        guard let result = bitmap.representation(using: .png, properties: [:]) else {
            throw TestFailure(message: "Could not encode test image")
        }
        return result
    }
}

@MainActor
private final class FakePasteboard: CapturePasteboard {
    private(set) var changeCount = 0
    private(set) var ids: [UInt8] = []
    private(set) var hasExternalContent = false
    var failNextWrite = false

    func replace(with items: [CaptureBatchItem]) -> Bool {
        clear()
        if failNextWrite {
            failNextWrite = false
            return false
        }
        ids = items.compactMap { $0.pngData.first }
        return true
    }

    func clear() {
        changeCount += 1
        ids = []
        hasExternalContent = false
    }

    func externalCopy() {
        clear()
        hasExternalContent = true
    }
}

private struct TestFailure: Error {
    let message: String
}
