import Cocoa

/// Protocol for all drawing commands.
/// Mirrors the C++ `DrawCmd` abstract class from x11-overlay.
public class DrawCmd {
    var x: Int = 0
    var y: Int = 0
    var w: Int
    var h: Int

    init(width: Int = 0, height: Int = 0) {
        self.w = width
        self.h = height
    }

    func draw(canvas: OverlayCanvas, alpha: Float) {
        // Abstract - subclasses override
    }
}

/// Sets the current drawing color on the canvas.
public final class DrawColorCmd: DrawCmd {
    let color: Color

    init(_ color: Color) {
        self.color = color
        super.init()
    }

    override func draw(canvas: OverlayCanvas, alpha: Float) {
        canvas.setColor(Color(
            Int(color.r),
            Int(color.g),
            Int(color.b),
            Int(Float(color.a) * alpha)
        ))
    }
}

/// Draws a filled rectangle (background) at the command's position.
public final class DrawRectCmd: DrawCmd {
    init(w: Int, h: Int) {
        super.init(width: w, height: h)
    }

    override func draw(canvas: OverlayCanvas, alpha: Float) {
        canvas.drawRect(x: x, y: y, w: w, h: h)
    }
}

/// Draws UTF-8 text (foreground) at the command's position.
public final class DrawTextCmd: DrawCmd {
    let text: String

    init(w: Int, h: Int, text: String) {
        self.text = text
        super.init(width: w, height: h)
    }

    override func draw(canvas: OverlayCanvas, alpha: Float) {
        canvas.drawString(x: x, y: y, text: text)
    }
}

/// Switches the active font by index.
public final class DrawSelectFontCmd: DrawCmd {
    let fontIndex: UInt

    init(fontIndex: UInt) {
        self.fontIndex = fontIndex
        super.init()
    }

    override func draw(canvas: OverlayCanvas, alpha: Float) {
        canvas.selectFont(fontIndex)
    }
}
