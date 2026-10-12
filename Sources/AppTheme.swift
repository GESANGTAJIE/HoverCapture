import AppKit

enum AppTheme {
    static let black = NSColor(srgbRed: 14 / 255, green: 13 / 255, blue: 12 / 255, alpha: 1)
    static let orange = NSColor(srgbRed: 1, green: 107 / 255, blue: 44 / 255, alpha: 1)
    static let white = NSColor(srgbRed: 247 / 255, green: 247 / 255, blue: 245 / 255, alpha: 1)
    static let secondary = NSColor(srgbRed: 105 / 255, green: 101 / 255, blue: 96 / 255, alpha: 1)

    static func icon(_ name: String) -> NSImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "pdf", subdirectory: "Icons"),
              let image = NSImage(contentsOf: url) else {
            NSLog("HoverCapture: could not load bundled icon %@", name)
            return nil
        }
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        return image
    }

    static func label(_ title: String, size: CGFloat = 13, weight: NSFont.Weight = .regular,
                      color: NSColor = black) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        return label
    }

    static func surface(_ color: NSColor) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = color.cgColor
        return view
    }
}
