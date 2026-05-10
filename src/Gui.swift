import Cocoa

/// The main rendering orchestrator.
/// Mirrors the C++ `Gui` class from x11-overlay.
public final class Gui {

    // MARK: - Orientation

    enum Orientation: Int, CaseIterable {
        case N = 0, NE, E, SE, S, SW, W, NW, CENTER, NONE
    }

    // MARK: - Properties

    var orientation: Orientation = .NW

    private var window: OverlayWindow
    private var canvas: OverlayCanvas
    private var lines: [Line] = []
    private var mouseOver: Bool = false
    private var redraw: Bool = true
    private var recalc: Bool = true
    private var increaseIntensity: Bool = false
    private var lastFgColor: String = "\u{1b}[37m"
    private var colorProfile: Ansi.Profile = .vga

    private var screenEdgeSpacing: Int = 0
    private var lineSpacing: Int = 0
    private var mouseOverTolerance: Int = 0
    private var alpha: Float = 0.25
    private var mouseOverAlpha: Float = 0.25
    private var fgColor: Color = Color(255, 255, 255, 200)
    private var bgColor: Color = Color(0, 0, 0, 100)

    // MARK: - Init

    init() {
        window = OverlayWindow(x: 0, y: 0, width: 480, height: 640)
        canvas = OverlayCanvas()

        setDefaultForegroundColor(Color(255, 255, 255, 200))
        setDefaultBackgroundColor(Color(0, 0, 0, 100))
        clearMessages()
    }

    // MARK: - Setters

    func setDefaultForegroundColor(_ color: Color) {
        redraw = true
        fgColor = color
    }

    func setDefaultBackgroundColor(_ color: Color) {
        redraw = true
        bgColor = color
    }

    func setColorProfile(_ profile: Ansi.Profile) {
        redraw = true
        colorProfile = profile
    }

    func setDimming(_ dimming: Float) {
        redraw = true
        self.alpha = 1.0 - dimming
    }

    func setMouseOverDimming(_ dimming: Float) {
        redraw = true
        self.mouseOverAlpha = 1.0 - dimming
    }

    func setMouseOverTolerance(_ tolerance: Int) {
        redraw = true
        mouseOverTolerance = tolerance
    }

    func setOrientation(_ orientation: Orientation) {
        redraw = true
        recalc = true
        self.orientation = orientation
    }

    func setScreenEdgeSpacing(_ spacing: Int) {
        redraw = true
        screenEdgeSpacing = spacing
    }

    func setLineSpacing(_ spacing: Int) {
        redraw = true
        recalc = true
        lineSpacing = spacing
    }

    func setMonitorIndex(_ index: Int) {
        redraw = true
        recalc = true
        window.setActiveMonitor(index)
    }

    func setFont(fontIndex: UInt, font: String) {
        redraw = true
        canvas.setFont(fontIndex: fontIndex, fontName: font)
    }

    // MARK: - Flush (Render Loop)

    func flush() {
        layoutLines()

        let currentMouseOver = isMouseOver()
        redraw = redraw || (mouseOver != currentMouseOver)
        let monitorChanged = window.isActiveMonitorChanged()
        if monitorChanged {
            _ = updateWindowPosition()
            redraw = true
        }
        mouseOver = currentMouseOver

        guard redraw else { return }

        performDraw()

        redraw = false
    }

    /// Renders all content into the off-screen bitmap and sets it as the layer contents.
    private func performDraw() {
        let w = window.getWidth()
        let h = window.getHeight()

        print("DEBUG performDraw: w=\(w) h=\(h) lines=\(lines.count)")

        canvas.ensureBitmap(width: w, height: h)
        canvas.clearBitmap()

        guard !lines.isEmpty else {
            window.setRenderedImage(nil)
            return
        }

        canvas.selectFont(0)

        let a = mouseOver ? mouseOverAlpha : alpha
        print("DEBUG performDraw: alpha=\(a) fgColor=\(fgColor) bgColor=\(bgColor)")

        // Draw all backgrounds first
        DrawColorCmd(bgColor).draw(canvas: canvas, alpha: a)
        for (i, line) in lines.enumerated() {
            print("DEBUG line[\(i)]: x=\(line.x) y=\(line.y) w=\(line.w) h=\(line.h) baseline=\(line.baseline) bgCmds=\(line.drawBgCommands.count) fgCmds=\(line.drawFgCommands.count)")
            line.drawBg(canvas: canvas, alpha: a)
        }

        // Then all foregrounds
        DrawColorCmd(fgColor).draw(canvas: canvas, alpha: a)
        for line in lines {
            line.drawFg(canvas: canvas, alpha: a)
        }

        // DEBUG: Save bitmap to PNG
        if let image = canvas.makeBitmapImage() {
            print("DEBUG: CGImage created: \(image.width)x\(image.height) bpc=\(image.bitsPerComponent) bpp=\(image.bitsPerPixel) alphaInfo=\(image.alphaInfo.rawValue)")
            let url = URL(fileURLWithPath: "/tmp/osx-overlay-debug.png")
            if let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) {
                CGImageDestinationAddImage(dest, image, nil)
                if CGImageDestinationFinalize(dest) {
                    print("DEBUG: Bitmap saved to /tmp/osx-overlay-debug.png")
                } else {
                    print("DEBUG: Failed to finalize PNG")
                }
            } else {
                print("DEBUG: Failed to create image destination")
            }
            // Set the rendered bitmap as the layer contents
            window.setRenderedImage(image)
        } else {
            print("DEBUG: makeBitmapImage() returned nil!")
            window.setRenderedImage(nil)
        }
    }

    // MARK: - Messages

    func clearMessages() {
        redraw = true
        recalc = true
        increaseIntensity = false
        lastFgColor = "\u{1b}[37m"
        lines.removeAll()
    }

    func addMessage(_ message: String) {
        redraw = true
        recalc = true

        var drawBgCommands: [DrawCmd] = []
        var drawFgCommands: [DrawCmd] = []

        let trimmedMessage = Gui.trimForOrientation(orientation, Gui.trimLinefeedsAndApplyTabs(message))
        var maxFontAscent: Int = 0

        for chunk in Ansi.split(trimmedMessage) {
            let sequence = Ansi.parseControlSequence(chunk)
            switch sequence {
            case .reset:
                increaseIntensity = false
                drawFgCommands.append(DrawColorCmd(fgColor))
                drawBgCommands.append(DrawColorCmd(bgColor))

            case .resetForeground:
                drawFgCommands.append(DrawColorCmd(fgColor))

            case .resetBackground:
                drawBgCommands.append(DrawColorCmd(bgColor))

            case .foregroundColor:
                lastFgColor = chunk
                drawFgCommands.append(DrawColorCmd(
                    Ansi.toColor(chunk, fallbackColor: fgColor, increaseIntensity: increaseIntensity, profile: colorProfile)
                ))

            case .backgroundColor:
                drawBgCommands.append(DrawColorCmd(
                    Ansi.toColor(chunk, fallbackColor: bgColor, increaseIntensity: false, profile: colorProfile)
                ))

            case .increaseIntensity:
                increaseIntensity = true
                drawFgCommands.append(DrawColorCmd(
                    Ansi.toColor(lastFgColor, fallbackColor: fgColor, increaseIntensity: increaseIntensity, profile: colorProfile)
                ))

            case .decreasedIntensity:
                increaseIntensity = false
                drawFgCommands.append(DrawColorCmd(
                    Ansi.toColor(lastFgColor, fallbackColor: fgColor, increaseIntensity: increaseIntensity, profile: colorProfile)
                ))

            case .normalIntensity:
                increaseIntensity = false
                drawFgCommands.append(DrawColorCmd(
                    Ansi.toColor(lastFgColor, fallbackColor: fgColor, increaseIntensity: increaseIntensity, profile: colorProfile)
                ))

            case .defaultFont, .alternativeFont:
                let selectedIndex = canvas.selectFont(UInt(Ansi.toFontIndex(chunk)))
                drawFgCommands.append(DrawSelectFontCmd(fontIndex: selectedIndex))

            case .none:
                maxFontAscent = max(maxFontAscent, canvas.getSelectedFontAscent())
                let chunkDim = canvas.getStringDimension(chunk)
                drawBgCommands.append(DrawRectCmd(w: chunkDim.w, h: chunkDim.h))
                drawFgCommands.append(DrawTextCmd(w: chunkDim.w, h: chunkDim.h, text: chunk))

            default:
                break
            }
        }

        lines.append(Line(
            baseline: maxFontAscent,
            drawBgCommands: drawBgCommands,
            drawFgCommands: drawFgCommands
        ))
    }

    // MARK: - Layout

    private func layoutLines() {
        guard recalc else { return }

        var maxW = 0
        var maxH = 0

        for line in lines {
            maxW = max(maxW, line.w)
        }

        for line in lines {
            line.x = calcXforOrientation(innerWidth: line.w, outerWidth: maxW, spacing: 0)
            line.y = maxH

            var cmdX = line.x
            for bgCmd in line.drawBgCommands {
                bgCmd.x = cmdX; cmdX += bgCmd.w
                bgCmd.y = line.y
                bgCmd.h = line.h
            }

            cmdX = line.x
            for fgCmd in line.drawFgCommands {
                fgCmd.x = cmdX; cmdX += fgCmd.w
                fgCmd.y = line.y + line.baseline
            }

            maxH += line.h + lineSpacing
        }

        window.resize(width: maxW, height: maxH)
        _ = updateWindowPosition()

        recalc = false
    }

    // MARK: - Text Processing

    static func trimLinefeedsAndApplyTabs(_ text: String) -> String {
        var result = ""
        var size = 0

        for c in text {
            switch c {
            case "\r", "\n":
                break
            case "\t":
                if size % 4 == 0 {
                    size += 4
                    result += "    "
                }
                while size % 4 != 0 {
                    size += 1
                    result += " "
                }
            default:
                result.append(c)
                size += 1
            }
        }
        return result
    }

    static func trimForOrientation(_ orientation: Orientation, _ text: String) -> String {
        // West orientations: keep original
        if orientation == .NW || orientation == .W || orientation == .SW {
            return text
        }

        let start = text.firstIndex(where: { $0 != " " })
        let end = text.lastIndex(where: { $0 != " " })

        if let s = start, let e = end, s == text.startIndex && text.index(after: e) == text.endIndex {
            return text
        }

        let safeStart = start ?? text.startIndex
        let safeEnd = end.map { text.index(after: $0) } ?? text.startIndex

        // Center orientations: strip both sides
        if orientation == .N || orientation == .CENTER || orientation == .S {
            return String(text[safeStart..<safeEnd])
        }

        // East orientations: swap left and right padding
        let leftPadding = String(text[text.startIndex..<safeStart])
        let middle = String(text[safeStart..<safeEnd])
        let rightPadding = String(text[safeEnd..<text.endIndex])
        return rightPadding + middle + leftPadding
    }

    // MARK: - Mouse Over Detection

    private func isMouseOver() -> Bool {
        let w = window.getWidth()
        let h = window.getHeight()
        let t = mouseOverTolerance

        let pos = window.getMousePosition()
        let isInFrame = pos.x + t >= 0 &&
            pos.y + t >= 0 &&
            pos.x - t < w &&
            pos.y - t < h

        if isInFrame {
            for line in lines {
                if pos.x + t >= line.x &&
                    pos.y + t >= line.y &&
                    pos.x - t <= line.x + line.w &&
                    pos.y - t <= line.y + line.h
                {
                    return true
                }
            }
        }
        return false
    }

    // MARK: - Orientation Helpers

    private func calcXforOrientation(innerWidth: Int, outerWidth: Int, spacing: Int) -> Int {
        switch orientation {
        case .NW, .W, .SW:
            return spacing
        case .N, .CENTER, .S:
            return outerWidth / 2 - innerWidth / 2
        case .NE, .E, .SE:
            return outerWidth - innerWidth - spacing
        case .NONE:
            return spacing
        }
    }

    private func calcYforOrientation(innerHeight: Int, outerHeight: Int, spacing: Int) -> Int {
        switch orientation {
        case .NW, .N, .NE:
            return spacing
        case .W, .CENTER, .E:
            return outerHeight / 2 - innerHeight / 2
        case .SW, .S, .SE:
            return outerHeight - innerHeight - spacing
        case .NONE:
            return spacing
        }
    }

    @discardableResult
    private func updateWindowPosition() -> Bool {
        window.move(
            x: calcXforOrientation(
                innerWidth: window.getWidth(),
                outerWidth: window.getMonitorWidth(),
                spacing: screenEdgeSpacing
            ),
            y: calcYforOrientation(
                innerHeight: window.getHeight(),
                outerHeight: window.getMonitorHeight(),
                spacing: screenEdgeSpacing
            )
        )
        return true
    }

    // MARK: - Orientation String Conversion

    static func orientationToString(_ orientation: Orientation) -> String {
        switch orientation {
        case .N: return "N"
        case .NE: return "NE"
        case .E: return "E"
        case .SE: return "SE"
        case .S: return "S"
        case .SW: return "SW"
        case .W: return "W"
        case .NW: return "NW"
        case .CENTER: return "CENTER"
        case .NONE: return ""
        }
    }

    static func orientationFromString(_ input: String) -> Orientation {
        for orientation in Orientation.allCases {
            if orientation != .NONE && input == orientationToString(orientation) {
                return orientation
            }
        }
        return .NONE
    }

    // MARK: - Window Access

    func showWindow() {
        window.show()
    }
}
