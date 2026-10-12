import AppKit

struct CaptureBatchItem {
    let pngData: Data
    let fileURL: URL?
}

@MainActor
protocol CapturePasteboard {
    var changeCount: Int { get }
    func replace(with items: [CaptureBatchItem]) -> Bool
    func clear()
}

@MainActor
final class SystemCapturePasteboard: CapturePasteboard {
    private let pasteboard: NSPasteboard

    init(_ pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    var changeCount: Int { pasteboard.changeCount }

    func replace(with items: [CaptureBatchItem]) -> Bool {
        guard !items.isEmpty else { return false }
        var objects: [NSPasteboardItem] = []
        for capture in items {
            let item = NSPasteboardItem()
            guard item.setData(capture.pngData, forType: .png) else { return false }
            if let fileURL = capture.fileURL {
                guard item.setString(fileURL.absoluteString, forType: .fileURL) else { return false }
            }
            objects.append(item)
        }
        pasteboard.clearContents()
        return pasteboard.writeObjects(objects)
    }

    func clear() { pasteboard.clearContents() }
}

@MainActor
final class CaptureBatch {
    static let capacityRange = 1...20
    private let pasteboard: CapturePasteboard
    private var items: [CaptureBatchItem] = []
    private var copiedChangeCount: Int?
    private var copiedLatestOnly = false
    private(set) var capacity: Int
    var count: Int { items.count }

    init(capacity: Int = 1, pasteboard: CapturePasteboard? = nil) {
        self.capacity = Self.clampedCapacity(capacity)
        self.pasteboard = pasteboard ?? SystemCapturePasteboard()
    }

    static func clampedCapacity(_ value: Int) -> Int {
        min(max(value, capacityRange.lowerBound), capacityRange.upperBound)
    }

    @discardableResult
    func setCapacity(_ value: Int) -> Bool {
        capacity = Self.clampedCapacity(value)
        guard items.count > capacity else { return true }
        items.removeFirst(items.count - capacity)
        // A settings change must not replace something copied in another app.
        return ownsClipboard && !copiedLatestOnly ? copyAll() : true
    }

    @discardableResult
    func append(pngData: Data, fileURL: URL?) -> Bool {
        items.append(CaptureBatchItem(pngData: pngData, fileURL: fileURL))
        if items.count > capacity { items.removeFirst(items.count - capacity) }
        return copyAll()
    }

    @discardableResult
    func copyAll() -> Bool { publish(items, latestOnly: false) }

    @discardableResult
    func copyLatest() -> Bool {
        guard let latest = items.last else { return false }
        return publish([latest], latestOnly: true)
    }

    func clear() {
        if ownsClipboard { pasteboard.clear() }
        copiedChangeCount = nil
        copiedLatestOnly = false
        items.removeAll()
    }

    private var ownsClipboard: Bool {
        copiedChangeCount == pasteboard.changeCount
    }

    private func publish(_ items: [CaptureBatchItem], latestOnly: Bool) -> Bool {
        guard !items.isEmpty else { return false }
        guard pasteboard.replace(with: items) else {
            copiedChangeCount = nil
            return false
        }
        copiedChangeCount = pasteboard.changeCount
        copiedLatestOnly = latestOnly
        return true
    }
}
