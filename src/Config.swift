import Foundation

/// Application configuration with three-tier resolution:
/// defaults -> config file -> command-line parameters.
/// Mirrors the C++ `Config` class from x11-overlay.
public final class Config {

    // MARK: - Constants

    private static let SECTION_NONE = ""
    private static let SECTION_NONE_INPUT_FILE = "InputFile"
    private static let SECTION_POSITIONING = "Positioning"
    private static let SECTION_POSITIONING_MONITOR_INDEX = "MonitorIndex"
    private static let SECTION_POSITIONING_ORIENTATION = "Orientation"
    private static let SECTION_POSITIONING_SCREEN_EDGE_SPACING = "ScreenEdgeSpacing"
    private static let SECTION_POSITIONING_LINE_SPACING = "LineSpacing"
    private static let SECTION_FONT = "Font"
    private static let SECTION_FONT_NAME = "Name"
    private static let SECTION_FONT_SIZE = "Size"
    private static let SECTION_COLORS = "Colors"
    private static let SECTION_COLORS_ANSI_PROFILE = "AnsiProfile"
    private static let SECTION_COLORS_FG_COLOR = "ForegroundColor"
    private static let SECTION_COLORS_FG_ALPHA = "ForegroundAlpha"
    private static let SECTION_COLORS_BG_COLOR = "BackgroundColor"
    private static let SECTION_COLORS_BG_ALPHA = "BackgroundAlpha"
    private static let SECTION_BEHAVIOR = "Behavior"
    private static let SECTION_BEHAVIOR_TOLERANCE = "Tolerance"
    private static let SECTION_BEHAVIOR_DIMMING = "Dimming"
    private static let SECTION_BEHAVIOR_MOUSE_OVER_DIMMING = "MouseOverDimming"

    // Sentinel value for "not set" integers
    private static let INT_UNSET = Int.min

    // MARK: - Properties

    var configFile: String = ""
    var verbose: Bool = false

    // Main
    var inputFile: String = ""

    // Positioning
    var monitorIndex: Int = Int.min
    var orientation: Gui.Orientation = .NONE
    var screenEdgeSpacing: Int = Int.min
    var lineSpacing: Int = Int.min

    // Font (up to 10)
    var fontName: [String] = Array(repeating: "", count: 10)
    var fontSize: [Int] = Array(repeating: 0, count: 10)

    // Colors
    var colorProfile: Ansi.Profile = .vga
    var tempDefaultForegroundColor: String = ""
    var tempDefaultBackgroundColor: String = ""
    var defaultForegroundColor: Color = Color.configUnset
    var defaultBackgroundColor: Color = Color.configUnset

    // Behavior
    var dimming: Int = Int.min
    var mouseOverDimming: Int = Int.min
    var mouseOverTolerance: Int = Int.min

    // MARK: - Init

    private init() {}

    // MARK: - Override

    /// Merges another config into this one. Only non-default values override.
    @discardableResult
    func overrideWith(_ other: Config) -> Config {
        let unset = Config()

        if other.configFile != unset.configFile { self.configFile = other.configFile }
        if other.verbose != unset.verbose { self.verbose = other.verbose }
        if other.inputFile != unset.inputFile { self.inputFile = other.inputFile }

        // Positioning
        if other.monitorIndex != unset.monitorIndex { self.monitorIndex = other.monitorIndex }
        if other.orientation != unset.orientation { self.orientation = other.orientation }
        if other.screenEdgeSpacing != unset.screenEdgeSpacing { self.screenEdgeSpacing = other.screenEdgeSpacing }
        if other.lineSpacing != unset.lineSpacing { self.lineSpacing = other.lineSpacing }

        // Font
        for i in 0..<10 {
            if other.fontName[i] != unset.fontName[i] { self.fontName[i] = other.fontName[i] }
            if other.fontSize[i] != unset.fontSize[i] { self.fontSize[i] = other.fontSize[i] }
        }

        // Colors
        if other.colorProfile != unset.colorProfile { self.colorProfile = other.colorProfile }
        if other.tempDefaultForegroundColor != unset.tempDefaultForegroundColor {
            self.tempDefaultForegroundColor = other.tempDefaultForegroundColor
        }
        if other.tempDefaultBackgroundColor != unset.tempDefaultBackgroundColor {
            self.tempDefaultBackgroundColor = other.tempDefaultBackgroundColor
        }
        if other.defaultForegroundColor != unset.defaultForegroundColor {
            self.defaultForegroundColor = other.defaultForegroundColor
        }
        if other.defaultBackgroundColor != unset.defaultBackgroundColor {
            self.defaultBackgroundColor = other.defaultBackgroundColor
        }

        // Behavior
        if other.dimming != unset.dimming { self.dimming = other.dimming }
        if other.mouseOverDimming != unset.mouseOverDimming { self.mouseOverDimming = other.mouseOverDimming }
        if other.mouseOverTolerance != unset.mouseOverTolerance { self.mouseOverTolerance = other.mouseOverTolerance }

        finalizeColors()

        return self
    }

    // MARK: - Print

    func print(to output: inout String) {
        output += "default config file path is '\(Config.getDefaultConfigFilePath())'\n"
        output += "---- resulting config ----\n"
        output += "\(Config.SECTION_NONE_INPUT_FILE)=\(inputFile)\n\n"

        output += "[\(Config.SECTION_POSITIONING)]\n"
        output += "\(Config.SECTION_POSITIONING_MONITOR_INDEX)=\(monitorIndex)\n"
        output += "\(Config.SECTION_POSITIONING_ORIENTATION)=\(Gui.orientationToString(orientation))\n"
        output += "\(Config.SECTION_POSITIONING_SCREEN_EDGE_SPACING)=\(screenEdgeSpacing)\n"
        output += "\(Config.SECTION_POSITIONING_LINE_SPACING)=\(lineSpacing)\n\n"

        output += "[\(Config.SECTION_FONT)]\n"
        let fontNameStr = fontName.joined(separator: ",").trimmingTrailingCommas()
        output += "\(Config.SECTION_FONT_NAME)=\(fontNameStr)\n"
        let fontSizeStr = fontSize.map { $0 != 0 ? String($0) : "" }.joined(separator: ",").trimmingTrailingCommas()
        output += "\(Config.SECTION_FONT_SIZE)=\(fontSizeStr)\n\n"

        output += "[\(Config.SECTION_COLORS)]\n"
        output += "\(Config.SECTION_COLORS_ANSI_PROFILE)=\(Ansi.profileToString(colorProfile))\n"
        output += "\(Config.SECTION_COLORS_FG_COLOR)=[38;2;\(defaultForegroundColor.r);\(defaultForegroundColor.g);\(defaultForegroundColor.b)m\n"
        output += "\(Config.SECTION_COLORS_FG_ALPHA)=\(defaultForegroundColor.a)\n"
        output += "\(Config.SECTION_COLORS_BG_COLOR)=[48;2;\(defaultBackgroundColor.r);\(defaultBackgroundColor.g);\(defaultBackgroundColor.b)m\n"
        output += "\(Config.SECTION_COLORS_BG_ALPHA)=\(defaultBackgroundColor.a)\n\n"

        output += "[\(Config.SECTION_BEHAVIOR)]\n"
        output += "\(Config.SECTION_BEHAVIOR_DIMMING)=\(dimming)\n"
        output += "\(Config.SECTION_BEHAVIOR_MOUSE_OVER_DIMMING)=\(mouseOverDimming)\n"
        output += "\(Config.SECTION_BEHAVIOR_TOLERANCE)=\(mouseOverTolerance)\n"
        output += "--------------------------\n"
    }

    // MARK: - Default Config

    static func defaultConfig() -> Config {
        let config = Config()
        config.configFile = ""
        config.verbose = false
        config.inputFile = ""

        // Positioning
        config.monitorIndex = 0
        config.orientation = .NW
        config.screenEdgeSpacing = 0
        config.lineSpacing = 0

        // Font
        config.fontName[0] = "NotoSansMono"
        config.fontSize[0] = 12

        // Colors
        config.colorProfile = .vga
        config.tempDefaultForegroundColor = ""
        config.tempDefaultBackgroundColor = ""
        config.defaultForegroundColor = Color(255, 255, 255, 255)
        config.defaultBackgroundColor = Color(0, 0, 0, 100)

        // Behavior
        config.dimming = 0
        config.mouseOverDimming = 75
        config.mouseOverTolerance = 0

        return config
    }

    // MARK: - From Parameters (CLI)

    static func fromParameters(_ args: [String]) -> Config {
        let config = Config()

        var i = 0
        while i < args.count {
            let arg = args[i]

            switch arg {
            case "-c", "--config":
                i += 1
                guard i < args.count else {
                    Swift.print("ERROR: option '\(arg)' needs a value")
                    exit(1)
                }
                config.configFile = args[i]

            case "-h", "--help":
                exitWithUsage(exitCode: 0)

            case "-v", "--verbose":
                config.verbose = true

            case "-V", "--version":
                exitWithVersionNumber()

            // Positioning
            case "-e":
                i += 1
                guard i < args.count else {
                    Swift.print("ERROR: option '\(arg)' needs a value")
                    exit(1)
                }
                config.screenEdgeSpacing = assertIntParameter(args[i], min: nil, max: nil, option: arg)

            case "-l":
                i += 1
                guard i < args.count else {
                    Swift.print("ERROR: option '\(arg)' needs a value")
                    exit(1)
                }
                config.lineSpacing = assertIntParameter(args[i], min: 0, max: nil, option: arg)

            case "-m":
                i += 1
                guard i < args.count else {
                    Swift.print("ERROR: option '\(arg)' needs a value")
                    exit(1)
                }
                config.monitorIndex = assertIntParameter(args[i], min: 0, max: nil, option: arg)

            case "-o":
                i += 1
                guard i < args.count else {
                    Swift.print("ERROR: option '\(arg)' needs a value")
                    exit(1)
                }
                config.orientation = assertOrientationParameter(args[i], option: arg)

            // Font
            case "-f", "--font-name":
                i += 1
                guard i < args.count else {
                    Swift.print("ERROR: option '\(arg)' needs a value")
                    exit(1)
                }
                assertFontNameParameter(args[i], config: config, option: arg)

            case "-s", "--font-size":
                i += 1
                guard i < args.count else {
                    Swift.print("ERROR: option '\(arg)' needs a value")
                    exit(1)
                }
                assertFontSizeParameter(args[i], config: config, option: arg)

            // Colors
            case "-p", "--profile":
                i += 1
                guard i < args.count else {
                    Swift.print("ERROR: option '\(arg)' needs a value")
                    exit(1)
                }
                config.colorProfile = assertProfileParameter(args[i], option: arg)

            case "--fg-color":
                i += 1
                guard i < args.count else {
                    Swift.print("ERROR: option '\(arg)' needs a value")
                    exit(1)
                }
                _ = assertAnsiColorParameter(args[i], colorProfile: config.colorProfile, option: arg)
                config.tempDefaultForegroundColor = args[i]

            case "--fg-alpha":
                i += 1
                guard i < args.count else {
                    Swift.print("ERROR: option '\(arg)' needs a value")
                    exit(1)
                }
                config.defaultForegroundColor.a = UInt8(clamping: assertIntParameter(args[i], min: 0, max: 255, option: arg))

            case "--bg-color":
                i += 1
                guard i < args.count else {
                    Swift.print("ERROR: option '\(arg)' needs a value")
                    exit(1)
                }
                _ = assertAnsiColorParameter(args[i], colorProfile: config.colorProfile, option: arg)
                config.tempDefaultBackgroundColor = args[i]

            case "--bg-alpha":
                i += 1
                guard i < args.count else {
                    Swift.print("ERROR: option '\(arg)' needs a value")
                    exit(1)
                }
                config.defaultBackgroundColor.a = UInt8(clamping: assertIntParameter(args[i], min: 0, max: 255, option: arg))

            // Behavior
            case "-d", "--dim":
                i += 1
                guard i < args.count else {
                    Swift.print("ERROR: option '\(arg)' needs a value")
                    exit(1)
                }
                config.mouseOverDimming = assertIntParameter(args[i], min: 0, max: 100, option: arg)

            case "-D":
                i += 1
                guard i < args.count else {
                    Swift.print("ERROR: option '\(arg)' needs a value")
                    exit(1)
                }
                config.dimming = assertIntParameter(args[i], min: 0, max: 100, option: arg)

            case "-t":
                i += 1
                guard i < args.count else {
                    Swift.print("ERROR: option '\(arg)' needs a value")
                    exit(1)
                }
                config.mouseOverTolerance = assertIntParameter(args[i], min: 0, max: nil, option: arg)

            default:
                // Non-option argument -> input file
                if !arg.hasPrefix("-") {
                    config.inputFile = arg
                } else {
                    // Check for --key=value format
                    if arg.contains("=") {
                        let parts = arg.split(separator: "=", maxSplits: 1)
                        if parts.count == 2 {
                            let key = String(parts[0])
                            let value = String(parts[1])
                            // Re-process with split key/value
                            let syntheticArgs = [key, value]
                            let subConfig = Config.fromParameters(syntheticArgs)
                            config.overrideWith(subConfig)
                        }
                    } else {
                        Swift.print("ERROR: unknown option '\(arg)'")
                        exit(1)
                    }
                }
            }

            i += 1
        }

        config.finalizeColors()
        return config
    }

    // MARK: - From File

    static func fromFile(_ filename: String, suppressWarning: Bool = false) -> Config {
        let config = Config()

        guard let content = try? String(contentsOfFile: filename, encoding: .utf8) else {
            if !suppressWarning {
                Swift.print("WARN: no (valid) config file found at '\(filename)'")
            }
            return config
        }

        let fileLines = content.components(separatedBy: .newlines)
        var section = ""
        var lineNum = 0

        for line in fileLines {
            defer { lineNum += 1 }

            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // Empty line
            if trimmedLine.isEmpty { continue }

            // Comment line
            if trimmedLine.hasPrefix(";") || trimmedLine.hasPrefix("#") { continue }

            // Section line
            if trimmedLine.hasPrefix("[") && trimmedLine.hasSuffix("]") && trimmedLine.count > 2 {
                section = String(trimmedLine.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
                continue
            }

            // Key=Value line
            if let eqIndex = line.firstIndex(of: "=") {
                let key = String(line[line.startIndex..<eqIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                let value = String(line[line.index(after: eqIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)

                if key.isEmpty || value.isEmpty { continue }

                do {
                    let parsed = try parseKeyValue(section: section, key: key, value: value, config: config)
                    if !parsed {
                        Swift.print("WARN: skipped line:\(lineNum)\t '\(line)' - not a comment, section nor a known key-value pair")
                    }
                } catch {
                    Swift.print("WARN: skipped line:\(lineNum)\t '\(line)' - \(error.localizedDescription)")
                }
                continue
            }

            Swift.print("WARN: skipped line:\(lineNum)\t '\(line)' - not a comment, section nor a known key-value pair")
        }

        config.finalizeColors()
        return config
    }

    private static func parseKeyValue(section: String, key: String, value: String, config: Config) throws -> Bool {
        if section == SECTION_NONE {
            if key == SECTION_NONE_INPUT_FILE {
                config.inputFile = value
                return true
            }
        }
        if section == SECTION_POSITIONING {
            if key == SECTION_POSITIONING_MONITOR_INDEX {
                config.monitorIndex = assertIntParameter(value, min: 0, max: nil, option: key)
                return true
            }
            if key == SECTION_POSITIONING_ORIENTATION {
                config.orientation = assertOrientationParameter(value, option: key)
                return true
            }
            if key == SECTION_POSITIONING_SCREEN_EDGE_SPACING {
                config.screenEdgeSpacing = assertIntParameter(value, min: nil, max: nil, option: key)
                return true
            }
            if key == SECTION_POSITIONING_LINE_SPACING {
                config.lineSpacing = assertIntParameter(value, min: 0, max: nil, option: key)
                return true
            }
        }
        if section == SECTION_FONT {
            if key == SECTION_FONT_NAME {
                assertFontNameParameter(value, config: config, option: key)
                return true
            }
            if key == SECTION_FONT_SIZE {
                assertFontSizeParameter(value, config: config, option: key)
                return true
            }
        }
        if section == SECTION_COLORS {
            if key == SECTION_COLORS_ANSI_PROFILE {
                config.colorProfile = assertProfileParameter(value, option: key)
                return true
            }
            if key == SECTION_COLORS_FG_COLOR {
                _ = assertAnsiColorParameter(value, colorProfile: config.colorProfile, option: key)
                config.tempDefaultForegroundColor = value
                return true
            }
            if key == SECTION_COLORS_FG_ALPHA {
                config.defaultForegroundColor.a = UInt8(clamping: assertIntParameter(value, min: 0, max: 255, option: key))
                return true
            }
            if key == SECTION_COLORS_BG_COLOR {
                _ = assertAnsiColorParameter(value, colorProfile: config.colorProfile, option: key)
                config.tempDefaultBackgroundColor = value
                return true
            }
            if key == SECTION_COLORS_BG_ALPHA {
                config.defaultBackgroundColor.a = UInt8(clamping: assertIntParameter(value, min: 0, max: 255, option: key))
                return true
            }
        }
        if section == SECTION_BEHAVIOR {
            if key == SECTION_BEHAVIOR_DIMMING {
                config.dimming = assertIntParameter(value, min: 0, max: 100, option: key)
                return true
            }
            if key == SECTION_BEHAVIOR_MOUSE_OVER_DIMMING {
                config.mouseOverDimming = assertIntParameter(value, min: 0, max: 100, option: key)
                return true
            }
            if key == SECTION_BEHAVIOR_TOLERANCE {
                config.mouseOverTolerance = assertIntParameter(value, min: 0, max: nil, option: key)
                return true
            }
        }
        return false
    }

    // MARK: - Color Finalization

    private func finalizeColors() {
        if !tempDefaultForegroundColor.isEmpty {
            let color = Config.assertAnsiColorParameter(
                tempDefaultForegroundColor,
                colorProfile: colorProfile,
                option: "ForegroundColor"
            )
            defaultForegroundColor.r = color.r
            defaultForegroundColor.g = color.g
            defaultForegroundColor.b = color.b
        }
        if !tempDefaultBackgroundColor.isEmpty {
            let color = Config.assertAnsiColorParameter(
                tempDefaultBackgroundColor,
                colorProfile: colorProfile,
                option: "BackgroundColor"
            )
            defaultBackgroundColor.r = color.r
            defaultBackgroundColor.g = color.g
            defaultBackgroundColor.b = color.b
        }
    }

    // MARK: - Parameter Validation

    @discardableResult
    private static func assertProfileParameter(_ param: String, option: String) -> Ansi.Profile {
        guard let profile = Ansi.profileFromString(param) else {
            Swift.print("ERROR: option '\(option)' must be [VGA,XP], but was '\(param)'")
            exit(1)
        }
        return profile
    }

    @discardableResult
    private static func assertOrientationParameter(_ param: String, option: String) -> Gui.Orientation {
        let orientation = Gui.orientationFromString(param)
        if orientation == .NONE {
            Swift.print("ERROR: option '\(option)' must be [N,NE,E,SE,S,SW,W,NW,CENTER], but was '\(param)'")
            exit(1)
        }
        return orientation
    }

    @discardableResult
    private static func assertIntParameter(_ param: String, min: Int?, max: Int?, option: String) -> Int {
        guard let value = Int(param) else {
            if !param.isEmpty && param.first == "-" {
                Swift.print("ERROR: option '\(option)' must have a value")
            } else {
                Swift.print("ERROR: option '\(option)' must be an integer value, but was '\(param)'")
            }
            exit(1)
        }
        if let minVal = min, value < minVal {
            Swift.print("ERROR: option '\(option)' must be in the range [\(minVal)..], but was '\(param)'")
            exit(1)
        }
        if let maxVal = max, value > maxVal {
            Swift.print("ERROR: option '\(option)' must be in the range [..\(maxVal)], but was '\(param)'")
            exit(1)
        }
        return value
    }

    @discardableResult
    private static func assertAnsiColorParameter(_ param: String, colorProfile: Ansi.Profile, option: String) -> Color {
        var colorSequence = param
        if !param.hasPrefix("\u{1b}") {
            colorSequence = "\u{1b}" + param
        }

        let fallbackColor = Color(0, 0, 0, 0)
        let seq = Ansi.parseControlSequence(colorSequence)
        switch seq {
        case .foregroundColor, .backgroundColor:
            let color = Ansi.toColor(colorSequence, fallbackColor: fallbackColor, increaseIntensity: false, profile: colorProfile)
            if color == fallbackColor {
                Swift.print("ERROR: option '\(option)' is an invalid ansi color sequence: '\(param)'")
                exit(1)
            }
            return color
        case .none:
            Swift.print("ERROR: option '\(option)' is neither an ansi sequence for fore- nor background color: '\(param)'")
            exit(1)
        default:
            Swift.print("ERROR: option '\(option)' is an ansi sequence, but must be one for fore- or background color: '\(param)'")
            exit(1)
        }
    }

    private static func assertFontNameParameter(_ param: String, config: Config, option: String) {
        let names = param.split(separator: ",", omittingEmptySubsequences: false).map { String($0) }
        for (i, name) in names.enumerated() {
            guard i <= 9 else {
                Swift.print("ERROR: option '\(option)' must be no more than 10 font names")
                exit(1)
            }
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            config.fontName[i] = trimmed
        }
    }

    private static func assertFontSizeParameter(_ param: String, config: Config, option: String) {
        let sizes = param.split(separator: ",", omittingEmptySubsequences: false).map { String($0) }
        for (i, sizeStr) in sizes.enumerated() {
            guard i <= 9 else {
                Swift.print("ERROR: option '\(option)' must be no more than 10 font sizes")
                exit(1)
            }
            let trimmed = sizeStr.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                config.fontSize[i] = assertIntParameter(trimmed, min: 1, max: nil, option: option)
            }
        }
    }

    // MARK: - Default Config Path

    static func getDefaultConfigFilePath() -> String {
        if let home = ProcessInfo.processInfo.environment["HOME"] {
            return home + "/.config/osx-overlayrc"
        }
        return NSHomeDirectory() + "/.config/osx-overlayrc"
    }

    // MARK: - Exit Helpers

    static func exitWithVersionNumber() {
        Swift.print("osx-overlay 1.0.0.RC")
        exit(0)
    }

    static func exitWithUsage(exitCode: Int32) {
        Swift.print("""
        usage: osx-overlay [OPTIONS] <INPUT_FILE>

          -c, --config=FILE       file path to read configuration from
          -h, --help              prints this help text
          -v, --verbose           be verbose and print some debug output
          -V, --version           print version number and quit

        Positioning:
          -e PIXEL                screen edge spacing in pixels; defaults to '0'
          -l PIXEL                line spacing in pixels; defaults to '0'
          -m INDEX                monitor to use; defaults to '0'
          -o ORIENTATION          orientation to align window and lines; defaults to 'NW'
                                  possible values are N, NE, E, SE, S, SW, W, NW and CENTER

        Font:
          -f, --font-name=FONT,.. font name; defaults to 'NotoSansMono'
          -s, --font-size=SIZE,.. font size; defaults to '12'

        Colors:
          -p, --profile=PROFILE   profile for ansi colors; values are VGA or XP
              --fg-color=COLOR    foreground color; defaults to '[97m' (equals '[38;2;255;255;255m')
              --fg-alpha=ALPHA    foreground alpha; defaults to '200'
              --bg-color=COLOR    background color; defaults to '[40m' (equals '[48;2;0;0;0m')
              --bg-alpha=ALPHA    background alpha; defaults to '100'

        Behavior:
          -d, --dim=PERCENT       dim the text on mouse over; defaults to '75'%
          -D PERCENT              dim the text in general; defaults to '0'%
          -t PIXEL                pixel tolerance for mouse over dimming; defaults to '0'
        """)
        exit(exitCode)
    }
}

// MARK: - String Extension

private extension String {
    /// Trims trailing commas from a string.
    func trimmingTrailingCommas() -> String {
        var s = self
        while s.hasSuffix(",") {
            s = String(s.dropLast())
        }
        return s
    }
}
