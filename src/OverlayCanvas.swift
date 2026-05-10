import Cocoa

/// Drawing canvas using Core Graphics for font rendering and color management.
/// Mirrors the C++ `X11Canvas` class from x11-overlay, adapted for macOS/Cocoa.
public final class OverlayCanvas {

    private var fonts: [UInt: NSFont] = [:]
    private var currentFontIndex: UInt = 0
    private var currentColor: NSColor = .black

    // Stored font names and sizes for recreating fonts
    private var fontNames: [UInt: String] = [:]
    private var fontSizes: [UInt: CGFloat] = [:]

    init() {
        // Load a default font
        setFont(fontIndex: 0, fontName: "NotoSansMono-12")
    }

    /// Sets a font at the given index. Font name format: "FontName-Size"
    /// (matching the Xft font naming convention used in x11-overlay).
    func setFont(fontIndex: UInt, fontName: String) {
        guard fontIndex <= 9 else { return }

        // Parse "FontName-Size" format
        var name = fontName
        var size: CGFloat = 12.0

        if let dashRange = fontName.range(of: "-", options: .backwards) {
            let sizeStr = String(fontName[dashRange.upperBound...])
            if let parsedSize = Double(sizeStr) {
                name = String(fontName[fontName.startIndex..<dashRange.lowerBound])
                size = CGFloat(parsedSize)
            }
        }

        fontNames[fontIndex] = name
        fontSizes[fontIndex] = size

        // Try to find the font by name, fall back to system monospaced
        let font: NSFont
        if let namedFont = NSFont(name: name, size: size) {
            font = namedFont
        } else if let monoFont = NSFont.monospacedSystemFont(ofSize: size, weight: .regular) as NSFont? {
            font = monoFont
        } else {
            font = NSFont.systemFont(ofSize: size)
        }

        // Close previous font at this index (ARC handles this in Swift)
        fonts[fontIndex] = font
    }

    /// Selects the active font by index. Falls back to current font if index has none.
    /// Returns the actually selected font index.
    @discardableResult
    func selectFont(_ index: UInt) -> UInt {
        if index <= 9, fonts[index] != nil {
            currentFontIndex = index
        }
        return currentFontIndex
    }

    /// Returns the ascent of the currently selected font.
    func getSelectedFontAscent() -> Int {
        guard let font = fonts[currentFontIndex] else { return 0 }
        return Int(ceil(font.ascender))
    }

    /// Sets the current drawing color with premultiplied alpha.
    func setColor(_ color: Color) {
        currentColor = NSColor(
            red: CGFloat(color.r) / 255.0,
            green: CGFloat(color.g) / 255.0,
            blue: CGFloat(color.b) / 255.0,
            alpha: CGFloat(color.a) / 255.0
        )
    }

    /// Draws a filled rectangle.
    func drawRect(x: Int, y: Int, w: Int, h: Int) {
        currentColor.setFill()
        let rect = NSRect(x: x, y: y, width: w, height: h)
        rect.fill()
    }

    /// Draws a UTF-8 string at the specified position.
    func drawString(x: Int, y: Int, text: String) {
        guard let font = fonts[currentFontIndex] else { return }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: currentColor
        ]

        // In x11-overlay, y is the baseline position.
        // In Cocoa, draw(at:) uses the top-left of the text bounding box.
        // We need to adjust: Cocoa y = baseline - ascent
        // But since we're drawing in a flipped view, y maps directly.
        let point = NSPoint(x: CGFloat(x), y: CGFloat(y))
        text.draw(at: point, withAttributes: attributes)
    }

    /// Measures the dimensions of a text string using the current font.
    func getStringDimension(_ text: String) -> IntPair {
        guard let font = fonts[currentFontIndex] else {
            return IntPair(w: 0, h: 0)
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font
        ]

        let size = (text as NSString).size(withAttributes: attributes)

        return IntPair(
            w: Int(ceil(size.width)),
            h: Int(ceil(font.ascender - font.descender))
        )
    }

    /// Returns the current font for external use.
    func getCurrentFont() -> NSFont? {
        return fonts[currentFontIndex]
    }
}
