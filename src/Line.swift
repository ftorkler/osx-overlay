import Foundation

/// Holds background and foreground draw commands for a single line of text.
/// Mirrors the C++ `Line` class from x11-overlay.
public final class Line {
    var x: Int = 0
    var y: Int = 0
    var w: Int = 0
    var h: Int = 0
    let baseline: Int
    let drawBgCommands: [DrawCmd]
    let drawFgCommands: [DrawCmd]

    init(baseline: Int, drawBgCommands: [DrawCmd], drawFgCommands: [DrawCmd]) {
        self.baseline = baseline
        self.drawBgCommands = drawBgCommands
        self.drawFgCommands = drawFgCommands

        // Calculate width and height from foreground commands
        for cmd in drawFgCommands {
            w += cmd.w
            h = max(h, cmd.h)
        }
    }

    func drawBg(canvas: OverlayCanvas, alpha: Float) {
        for cmd in drawBgCommands {
            cmd.draw(canvas: canvas, alpha: alpha)
        }
    }

    func drawFg(canvas: OverlayCanvas, alpha: Float) {
        for cmd in drawFgCommands {
            cmd.draw(canvas: canvas, alpha: alpha)
        }
    }
}
