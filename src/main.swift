import Cocoa

class TextDrawView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Define the text and attributes
        let text = "Hello, macOS!"
        let font = NSFont.boldSystemFont(ofSize: 24)
        let color = NSColor.white

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]

        // Draw the text at a specific position (e.g., center of the view)
        let position = CGPoint(x: 50, y: 100)
        text.draw(at: position, withAttributes: attributes)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        window.orderFrontRegardless()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

func createTextField(text: String, size: Int, color: Color = Color(255,255,255,255)) -> NSTextField {
    let attributedString = NSAttributedString(string: text, attributes: [
        .foregroundColor: NSColor(red: CGFloat(color.r)/255.0, green: CGFloat(color.g)/255.0, blue: CGFloat(color.b)/255.0, alpha: CGFloat(color.a)/255.0),
        .font: NSFont.systemFont(ofSize: CGFloat(size))
    ])

    // let boundingBox = attributedString.boundingRect()
    // let frame = NSRect(x: 200, y: 200, width: 800, height: 600)

    let label = NSTextField()
    label.isEditable = false
    label.isBezeled = false
    label.drawsBackground = false
    label.isSelectable = false
    label.attributedStringValue = attributedString
    return label
}

func buildLine(word1Color: NSColor, word1Size: CGFloat,
               word2Color: NSColor, word2Size: CGFloat) -> NSAttributedString {
    let result = NSMutableAttributedString()

    let part1 = NSAttributedString(string: "Hello ", attributes: [
        .foregroundColor: word1Color,
        .font: NSFont.systemFont(ofSize: word1Size)
    ])
    let part2 = NSAttributedString(string: "world!", attributes: [
        .foregroundColor: word2Color,
        .font: NSFont.systemFont(ofSize: word2Size)
    ])

    result.append(part1)
    result.append(part2)
    return result
}

func makeLabel(frame: NSRect, attributedString: NSAttributedString) -> NSTextField {
    let label = NSTextField(frame: frame)
    label.isEditable = false
    label.isBezeled = false
    label.drawsBackground = false
    label.isSelectable = false
    label.attributedStringValue = attributedString
    return label
}

func createWindow() -> NSWindow {
    let frame = NSRect(x: 200, y: 200, width: 800, height: 600)

    let window = NSWindow(
        contentRect: frame,
        styleMask: .borderless,
        backing: .buffered,
        defer: false
    )

    window.title = "OSX Overlay"

    // Fully transparent background
    window.isOpaque = false
    window.backgroundColor = .clear

    // Always on top, no focus, ignore input
    window.level = NSWindow.Level(rawValue: 1000) // NSScreenSaverWindowLevel
    window.ignoresMouseEvents = true
    window.hidesOnDeactivate = false

    // Line 1: "Hello" red 20pt, "world!" green 24pt
    let line1 = buildLine(word1Color: .red, word1Size: 20,
                          word2Color: .green, word2Size: 24)
    let label1 = makeLabel(frame: NSRect(x: 20, y: 310, width: 760, height: 40),
                           attributedString: line1)

    // Line 2: "Hello" blue 28pt, "world!" yellow 32pt
    let line2 = buildLine(word1Color: .blue, word1Size: 22,
                          word2Color: .yellow, word2Size: 32)
    let label2 = makeLabel(frame: NSRect(x: 20, y: 260, width: 760, height: 50),
                           attributedString: line2)

    let contentView = TextDrawView()
    contentView.translatesAutoresizingMaskIntoConstraints = false
    window.contentView = contentView

    // window.contentView?.addSubview(label1)
    // window.contentView?.addSubview(label2)

    return window
}

// ── main ────────────────────────────────────────────────────────────

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
delegate.window = createWindow()

let test = Color(1, 1, 1, 1);

app.delegate = delegate
app.run()
