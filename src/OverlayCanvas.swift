import Cocoa

/// Drawing canvas using Core Graphics for font rendering and color management.
/// Mirrors the C++ `X11Canvas` class from x11-overlay, adapted for macOS/Cocoa.
///
/// Unlike AppKit's implicit drawing context (which only exists inside NSView.draw()),
/// this canvas manages its own off-screen CGContext bitmap. Drawing commands write to
/// this bitmap, and the result is set as the CALayer's contents. This mirrors the X11
/// persistent drawable model where pixels persist until explicitly cleared.
public final class OverlayCanvas {

    private var fonts: [UInt: NSFont] = [:]
    private var currentFontIndex: UInt = 0
    private var currentColor: NSColor = .black

    // Stored font names and sizes for recreating fonts
    private var fontNames: [UInt: String] = [:]
    private var fontSizes: [UInt: CGFloat] = [:]

    // Off-screen bitmap context for persistent rendering
    private(set) var bitmapContext: CGContext?
    private(set) var bitmapWidth: Int = 0
    private(set) var bitmapHeight: Int = 0

    init() {
        // Load a default font
        setFont(fontIndex: 0, fontName: "NotoSansMono-12")
    }

    /// Creates or resizes the off-screen bitmap context.
    func ensureBitmap(width: Int, height: Int) {
        let w = max(width, 1)
        let h = max(height, 1)
        guard w != bitmapWidth || h != bitmapHeight else { return }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        guard let ctx = CGContext(
            data: nil,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: w * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return }

        // Flip the coordinate system so (0,0) is top-left (matching X11)
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: 1, y: -1)

        bitmapContext = ctx
        bitmapWidth = w
        bitmapHeight = h
    }

    /// Clears the entire bitmap to transparent.
    func clearBitmap() {
        guard let ctx = bitmapContext else { return }
        ctx.saveGState()
        // Reset transform to identity for the clear operation
        ctx.concatenate(ctx.ctm.inverted())
        ctx.clear(CGRect(x: 0, y: 0, width: bitmapWidth, height: bitmapHeight))
        ctx.restoreGState()
    }

    /// Returns a CGImage of the current bitmap contents.
    func makeBitmapImage() -> CGImage? {
        return bitmapContext?.makeImage()
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

    /// Draws a filled rectangle into the off-screen bitmap.
    func drawRect(x: Int, y: Int, w: Int, h: Int) {
        guard let ctx = bitmapContext else { return }
        ctx.setFillColor(currentColor.cgColor)
        ctx.fill(CGRect(x: x, y: y, width: w, height: h))
    }

    /// Draws a UTF-8 string at the specified position into the off-screen bitmap.
    func drawString(x: Int, y: Int, text: String) {
        guard let ctx = bitmapContext else { return }
        guard let font = fonts[currentFontIndex] else { return }

        // Push an NSGraphicsContext wrapping our bitmap CGContext so that
        // NSString.draw(at:withAttributes:) works outside of NSView.draw().
        let nsContext = NSGraphicsContext(cgContext: ctx, flipped: true)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsContext

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: currentColor
        ]

        // In x11-overlay, y is the baseline position.
        // In our flipped bitmap context, y increases downward just like X11.
        // NSString.draw(at:) expects the top of the glyph bounding box,
        // so we need to subtract the ascent to convert from baseline to top.
        let drawY = CGFloat(y) - font.ascender
        let point = NSPoint(x: CGFloat(x), y: drawY)
        text.draw(at: point, withAttributes: attributes)

        NSGraphicsContext.restoreGraphicsState()
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
