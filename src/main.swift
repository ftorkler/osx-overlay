import Cocoa
import Foundation

// MARK: - Constants

let LINE_LIMIT = 100
let CHECK_GUI_INTERVAL_MS: UInt32 = 50

// MARK: - Globals
var gui: Gui?
var running = true

// MARK: - Signal Handling

func sigHandler(_ signum: Int32) {
    running = false
    CFRunLoopStop(CFRunLoopGetMain())
}

func catchSigterm() {
    signal(SIGINT, sigHandler)
    signal(SIGTERM, sigHandler)
}

// MARK: - Input File Loading

func loadInputFile(_ filename: String) {
    guard let gui = gui else { return }
    gui.clearMessages()

    guard let content = try? String(contentsOfFile: filename, encoding: .utf8) else {
        print("ERROR: cannot read input file '\(filename)'")
        return
    }

    let lines = content.components(separatedBy: "\n")
    for (i, line) in lines.enumerated() {
        if i >= LINE_LIMIT { break }
        gui.addMessage(line)
    }
}

// MARK: - Config Reading

func readConfig() -> Config {
    // Skip the first argument (program name) and filter out macOS-injected args
    let allArgs = CommandLine.arguments
    var args: [String] = []
    var skipNext = false
    for (i, arg) in allArgs.enumerated() {
        if i == 0 { continue } // skip program name
        if skipNext { skipNext = false; continue }
        // Skip macOS-injected arguments like -NSDocumentRevisionsDebugMode
        if arg.hasPrefix("-NS") || arg.hasPrefix("-Apple") {
            skipNext = true
            continue
        }
        args.append(arg)
    }

    let configFromParameters = Config.fromParameters(args)
    let configFromFile: Config
    if !configFromParameters.configFile.isEmpty {
        configFromFile = Config.fromFile(configFromParameters.configFile, suppressWarning: false)
    } else {
        configFromFile = Config.fromFile(Config.getDefaultConfigFilePath(), suppressWarning: true)
    }

    let config = Config.defaultConfig()
        .overrideWith(configFromFile)
        .overrideWith(configFromParameters)

    if config.inputFile.isEmpty {
        print("ERROR: parameter 'INPUT_FILE' needs a value")
        print("")
        Config.exitWithUsage(exitCode: 1)
    }

    if config.verbose {
        var output = ""
        config.print(to: &output)
        Swift.print(output)
    }

    return config
}

// MARK: - Application Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var timer: Timer?
    var config: Config!
    var fileWatcher: FileWatcher!

    func applicationDidFinishLaunching(_ notification: Notification) {
        config = readConfig()
        fileWatcher = FileWatcher(config.inputFile)

        gui = Gui()

        // Positioning
        gui!.setOrientation(config.orientation)
        gui!.setScreenEdgeSpacing(config.screenEdgeSpacing)
        gui!.setLineSpacing(config.lineSpacing)
        gui!.setMonitorIndex(config.monitorIndex)

        // Font
        for i in 0..<10 {
            let fontName = !config.fontName[i].isEmpty ? config.fontName[i] : config.fontName[0]
            let fontSize = config.fontSize[i] != 0 ? config.fontSize[i] : config.fontSize[0]
            if !config.fontName[i].isEmpty || config.fontSize[i] != 0 {
                gui!.setFont(fontIndex: UInt(i), font: fontName + "-" + String(fontSize))
            }
        }

        // Colors
        gui!.setColorProfile(config.colorProfile)
        gui!.setDefaultForegroundColor(config.defaultForegroundColor)
        gui!.setDefaultBackgroundColor(config.defaultBackgroundColor)

        // Behavior
        gui!.setDimming(Float(config.dimming) / 100.0)
        gui!.setMouseOverDimming(Float(config.mouseOverDimming) / 100.0)
        gui!.setMouseOverTolerance(config.mouseOverTolerance)

        // Load the input file
        loadInputFile(config.inputFile)

        // Show the window
        gui!.showWindow()

        // Start the render loop timer (every 50ms)
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(CHECK_GUI_INTERVAL_MS) / 1000.0, repeats: true) { [weak self] _ in
            guard running else {
                self?.timer?.invalidate()
                NSApp.terminate(nil)
                return
            }

            if self?.fileWatcher.hasFileBeenRewritten() == true {
                if let inputFile = self?.config.inputFile {
                    loadInputFile(inputFile)
                }
            }

            gui?.flush()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// MARK: - Main Entry Point

catchSigterm()

let app = NSApplication.shared
// app.setActivationPolicy(.accessory) // No dock icon, no menu bar
let delegate = AppDelegate()
app.delegate = delegate
app.run()
