import Cocoa

/// Custom NSView that displays a CGImage as its layer contents.
/// Uses a layer-backed approach for reliable rendering — the bitmap
/// is drawn off-screen and set as the layer contents, which persists
/// across window server compositing cycles.
final class OverlayContentView: NSView {
    private var renderedImage: CGImage?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    override var wantsUpdateLayer: Bool { return true }

    override func makeBackingLayer() -> CALayer {
        let layer = CALayer()
        layer.isOpaque = false
        layer.contentsGravity = .topLeft
        layer.contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1.0
        return layer
    }

    override func updateLayer() {
        layer?.contents = renderedImage
    }

    /// Sets the rendered bitmap as the layer contents and triggers a display.
    func setRenderedImage(_ image: CGImage?) {
        renderedImage = image
        needsDisplay = true
    }
}

/// Manages the macOS overlay window.
/// Mirrors the C++ `X11Window` class from x11-overlay.
/// Creates a borderless, transparent, always-on-top, click-through window.
public final class OverlayWindow {

    private(set) var window: NSWindow
    private(set) var contentView: OverlayContentView
    private var windowX: Int
    private var windowY: Int
    private var windowWidth: Int
    private var windowHeight: Int
    private var monitorIndex: Int = 0
    private var lastMonitorFrame: NSRect = .zero

    init(x: Int, y: Int, width: Int, height: Int) {
        self.windowX = x
        self.windowY = y
        self.windowWidth = width
        self.windowHeight = height

        let frame = NSRect(x: x, y: y, width: width, height: height)

        window = NSWindow(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        // Fully transparent background
        window.isOpaque = false
        window.backgroundColor = .clear

        // Always on top - override_redirect equivalent
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)) + 1)

        // Click-through - equivalent to empty XFixes input shape region
        window.ignoresMouseEvents = true

        // Don't hide when app loses focus
        window.hidesOnDeactivate = false

        // Don't show in mission control / expose
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        // Create content view
        contentView = OverlayContentView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        window.contentView = contentView

        setActiveMonitor(0)
    }

    func setActiveMonitor(_ index: Int) {
        self.monitorIndex = index
    }

    /// Checks if the active monitor's geometry has changed.
    /// Returns true if a change was detected (and updates internal state).
    func isActiveMonitorChanged() -> Bool {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return false }

        let index = min(monitorIndex, screens.count - 1)
        let screen = screens[index]
        let frame = screen.frame

        let changed = lastMonitorFrame != frame
        if changed {
            lastMonitorFrame = frame
        }
        return changed
    }

    func getMonitorWidth() -> Int {
        return Int(lastMonitorFrame.width)
    }

    func getMonitorHeight() -> Int {
        return Int(lastMonitorFrame.height)
    }

    func getWidth() -> Int {
        return windowWidth
    }

    func getHeight() -> Int {
        return windowHeight
    }

    /// Moves the window to the given position relative to the active monitor.
    func move(x: Int, y: Int) {
        if self.windowX != x || self.windowY != y {
            self.windowX = x
            self.windowY = y

            // Convert from top-left origin (X11-style) to bottom-left origin (Cocoa)
            let screenHeight = lastMonitorFrame.height
            let cocoaY = lastMonitorFrame.origin.y + screenHeight - CGFloat(y) - CGFloat(windowHeight)
            let cocoaX = lastMonitorFrame.origin.x + CGFloat(x)
            window.setFrameOrigin(NSPoint(x: cocoaX, y: cocoaY))
        }
    }

    /// Resizes the window.
    func resize(width: Int, height: Int) {
        if self.windowWidth != width || self.windowHeight != height {
            self.windowWidth = width
            self.windowHeight = height

            // Preserve top-left position when resizing (Cocoa anchors at bottom-left)
            let screenHeight = lastMonitorFrame.height
            let cocoaY = lastMonitorFrame.origin.y + screenHeight - CGFloat(windowY) - CGFloat(height)
            let cocoaX = lastMonitorFrame.origin.x + CGFloat(windowX)

            let newFrame = NSRect(x: cocoaX, y: cocoaY, width: CGFloat(width), height: CGFloat(height))
            window.setFrame(newFrame, display: false)
            contentView.frame = NSRect(x: 0, y: 0, width: width, height: height)
        }
    }

    /// Returns the mouse position relative to the window.
    func getMousePosition() -> Position {
        let mouseLocation = NSEvent.mouseLocation
        let windowFrame = window.frame

        // Convert to window-relative coordinates with top-left origin
        let relX = Int(mouseLocation.x - windowFrame.origin.x)
        let relY = Int(windowFrame.origin.y + windowFrame.height - mouseLocation.y)

        return Position(x: relX, y: relY)
    }

    /// Updates the layer contents with a rendered bitmap image.
    func setRenderedImage(_ image: CGImage?) {
        contentView.setRenderedImage(image)
    }

    /// Shows the window.
    func show() {
        window.orderFrontRegardless()
    }
}
