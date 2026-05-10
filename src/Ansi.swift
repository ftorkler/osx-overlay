import Foundation

/// ANSI escape sequence parser and color converter.
/// Mirrors the C++ `Ansi` class from x11-overlay.
public final class Ansi {

    // MARK: - Constants

    static let ANSI_INIT = "\u{1b}["
    static let ANSI_START: Character = "\u{1b}"
    static let ANSI_END: Character = "m"
    static let ANSI_DELIMITER: Character = ";"

    // MARK: - Enums

    enum Sequence {
        case none
        case foregroundColor
        case backgroundColor
        case increaseIntensity
        case decreasedIntensity
        case normalIntensity
        case reset
        case resetForeground
        case resetBackground
        case defaultFont
        case alternativeFont
        case unknown
    }

    enum Profile: Int, CaseIterable {
        case vga = 0
        case xp = 1
    }

    // MARK: - Profile Conversion

    static func profileToString(_ profile: Profile) -> String {
        switch profile {
        case .vga: return "VGA"
        case .xp: return "XP"
        }
    }

    static func profileFromString(_ input: String) -> Profile? {
        for profile in Profile.allCases {
            if input == profileToString(profile) {
                return profile
            }
        }
        return nil
    }

    // MARK: - Color Conversion

    /// Converts an ANSI escape sequence string to a Color.
    /// Supports 3/4-bit, 8-bit and 24-bit ANSI color codes.
    static func toColor(
        _ ansi: String,
        fallbackColor: Color,
        increaseIntensity: Bool = false,
        profile: Profile = .xp
    ) -> Color {
        guard ansi.hasPrefix(ANSI_INIT),
              ansi.last == ANSI_END else {
            return fallbackColor
        }

        let prefixFgColor = "\u{1b}[38"
        let prefixBgColor = "\u{1b}[48"
        let prefixColorLen = 4
        let infixColor8bit = ";5;"
        let infixColor24bit = ";2;"
        let prefixColor8bitLen = 7
        let prefixColor24bitLen = 7

        // Check for extended color sequences (38;... or 48;...)
        if ansi.hasPrefix(prefixFgColor) || ansi.hasPrefix(prefixBgColor) {
            // 24-bit: ESC[38;2;r;g;bm or ESC[48;2;r;g;bm
            let afterPrefix = String(ansi.dropFirst(prefixColorLen))
            if afterPrefix.hasPrefix(infixColor24bit) {
                let colorCode = String(ansi.dropFirst(prefixColor24bitLen).dropLast(1))
                return _to24bitColor(colorCode, fallbackColor: fallbackColor)
            }
            // 8-bit: ESC[38;5;<code>m or ESC[48;5;<code>m
            if afterPrefix.hasPrefix(infixColor8bit) {
                let colorCode = String(ansi.dropFirst(prefixColor8bitLen).dropLast(1))
                if let code = Int(colorCode) {
                    return _to8bitColor(code, fallbackColor: fallbackColor, profile: profile)
                }
                return fallbackColor
            }
        }

        // 3/4-bit colors
        let inner = String(ansi.dropFirst(2).dropLast(1)) // strip ESC[ and m
        if !inner.contains(";"), inner.count >= 2 {
            if let colorCode = Int(inner) {
                if colorCode >= 30 && colorCode <= 37 {
                    let intensityLift = increaseIntensity ? 8 : 0
                    return _to8bitColor(colorCode - 30 + intensityLift, fallbackColor: fallbackColor, profile: profile)
                }
                if colorCode >= 40 && colorCode <= 47 {
                    let intensityLift = increaseIntensity ? 8 : 0
                    return _to8bitColor(colorCode - 40 + intensityLift, fallbackColor: fallbackColor, profile: profile)
                }
                if colorCode >= 90 && colorCode <= 97 {
                    return _to8bitColor(colorCode - 90 + 8, fallbackColor: fallbackColor, profile: profile)
                }
                if colorCode >= 100 && colorCode <= 107 {
                    return _to8bitColor(colorCode - 100 + 8, fallbackColor: fallbackColor, profile: profile)
                }
            }
        }

        return fallbackColor
    }

    // MARK: - 24-bit Color

    private static func _to24bitColor(_ code: String, fallbackColor: Color) -> Color {
        if code.isEmpty { return fallbackColor }

        let tokens = code.split(separator: Character(";"), omittingEmptySubsequences: false)
            .map { $0.isEmpty ? 0 : (Int($0) ?? 0) }

        // Handle trailing delimiter
        var allTokens = tokens
        if code.last == ";" {
            allTokens.append(0)
        }

        if allTokens.count >= 3 {
            let r = allTokens[0]
            let g = allTokens[1]
            let b = allTokens[2]
            if r >= 0 && r <= 255 && g >= 0 && g <= 255 && b >= 0 && b <= 255 {
                return Color(r, g, b, 255)
            }
        }
        return fallbackColor
    }

    // MARK: - 8-bit Color

    private static func _to8bitColor(_ code: Int, fallbackColor: Color, profile: Profile = .xp) -> Color {
        // 16 palette colors per profile
        let colors: [[Color]] = [
            // VGA
            [
                Color(0,0,0,255),       // 00: black
                Color(170,0,0,255),     // 01: red
                Color(0,170,0,255),     // 02: green
                Color(170,85,0,255),    // 03: yellow
                Color(0,0,170,255),     // 04: blue
                Color(170,0,170,255),   // 05: magenta
                Color(0,170,170,255),   // 06: cyan
                Color(170,170,170,255), // 07: white
                // high-intensity
                Color(85,85,85,255),    // 08: bright black
                Color(255,85,85,255),   // 09: bright red
                Color(85,255,85,255),   // 10: bright green
                Color(255,255,85,255),  // 11: bright yellow
                Color(85,85,255,255),   // 12: bright blue
                Color(255,85,255,255),  // 13: bright magenta
                Color(85,255,255,255),  // 14: bright cyan
                Color(255,255,255,255), // 15: bright white
            ],
            // Windows XP
            [
                Color(0,0,0,255),       // 00: black
                Color(128,0,0,255),     // 01: red
                Color(0,128,0,255),     // 02: green
                Color(128,128,0,255),   // 03: yellow
                Color(0,0,128,255),     // 04: blue
                Color(128,0,128,255),   // 05: magenta
                Color(0,128,128,255),   // 06: cyan
                Color(192,192,192,255), // 07: white
                // high-intensity
                Color(128,128,128,255), // 08: bright black
                Color(255,0,0,255),     // 09: bright red
                Color(0,255,0,255),     // 10: bright green
                Color(255,255,0,255),   // 11: bright yellow
                Color(0,0,255,255),     // 12: bright blue
                Color(255,0,255,255),   // 13: bright magenta
                Color(0,255,255,255),   // 14: bright cyan
                Color(255,255,255,255), // 15: bright white
            ]
        ]

        guard code >= 0 && code <= 255 else { return fallbackColor }

        if code < 16 {
            return colors[profile.rawValue][code]
        }

        // Grayscale ramp: codes 232-255
        if code > 231 {
            let s = (code - 232) * 10 + 8
            return Color(s, s, s, 255)
        }

        // 6x6x6 color cube: codes 16-231
        let n = code - 16
        let b = n % 6
        let g = ((n - b) / 6) % 6
        let r = ((n - b - g * 6) / 36) % 6

        return Color(
            r != 0 ? r * 40 + 55 : 0,
            g != 0 ? g * 40 + 55 : 0,
            b != 0 ? b * 40 + 55 : 0,
            255
        )
    }

    // MARK: - Font Index

    /// Extracts font index from ESC[10m..ESC[19m sequences.
    static func toFontIndex(_ ansi: String) -> UInt {
        guard ansi.count == 5,
              ansi.hasPrefix(ANSI_INIT),
              ansi.last == ANSI_END else {
            return 0
        }

        let chars = Array(ansi)
        let digit1 = chars[2]
        let digit2 = chars[3]

        guard digit1 == "1" else { return 0 }

        switch digit2 {
        case "0": return 0
        case "1": return 1
        case "2": return 2
        case "3": return 3
        case "4": return 4
        case "5": return 5
        case "6": return 6
        case "7": return 7
        case "8": return 8
        case "9": return 9
        default: return 0
        }
    }

    // MARK: - Parse Control Sequence

    /// Classifies an ANSI escape sequence into its Sequence type.
    static func parseControlSequence(_ text: String) -> Sequence {
        guard text.count >= 3,
              text.hasPrefix(ANSI_INIT),
              text.last == ANSI_END else {
            return .none
        }

        // Extract the code portion (between ESC[ and the first ; or m)
        let inner = String(text.dropFirst(2).dropLast(1)) // between ESC[ and m
        let code: String
        if let delimPos = inner.firstIndex(of: ";") {
            code = String(inner[inner.startIndex..<delimPos])
        } else {
            code = inner
        }

        guard code.count <= 3 else { return .unknown }
        guard let codeNum = Int(code) else { return .unknown }

        switch codeNum {
        case 0: return .reset
        case 1: return .increaseIntensity
        case 2: return .decreasedIntensity
        case 10: return .defaultFont
        case 11, 12, 13, 14, 15, 16, 17, 18, 19: return .alternativeFont
        case 22: return .normalIntensity
        case 39: return .resetForeground
        case 49: return .resetBackground
        case 30, 31, 32, 33, 34, 35, 36, 37, 38,
             90, 91, 92, 93, 94, 95, 96, 97, 98:
            return .foregroundColor
        case 40, 41, 42, 43, 44, 45, 46, 47, 48,
             100, 101, 102, 103, 104, 105, 106, 107, 108:
            return .backgroundColor
        default: return .unknown
        }
    }

    // MARK: - Split

    /// Splits a line of text into alternating segments of plain text and
    /// individual ANSI control sequences. Compound sequences like
    /// ESC[0;1;33;43m are decomposed into individual sequences.
    static func split(_ text: String) -> [String] {
        guard !text.isEmpty else { return [] }

        let chars = Array(text)
        var result: [String] = []
        var start = 0

        // Determine whether text starts with an ANSI sequence
        let startsWithAnsi = chars.count >= 2 &&
            chars[0] == Character("\u{1b}") &&
            chars[1] == Character("[")

        // i toggles between 0 (looking for ESC[) and 1 (looking for m)
        var i = startsWithAnsi ? 1 : 0

        let tokens: [String] = [ANSI_INIT, String(ANSI_END)]

        while start < chars.count {
            let searchStr = tokens[i]
            let searchFrom = String(chars[start...])

            guard let range = searchFrom.range(of: searchStr) else {
                break
            }

            let offset = searchFrom.distance(from: searchFrom.startIndex, to: range.lowerBound)
            let end = start + offset + (i == 1 ? 1 : 0) // include 'm' when looking for end

            if end > start {
                let chunk = String(chars[start..<end])
                subsplit(chunk, result: &result)
            }

            start = end
            i = (i + 1) % 2
        }

        if start < chars.count {
            let remaining = String(chars[start...])
            subsplit(remaining, result: &result)
        }

        return result
    }

    // MARK: - Subsplit

    /// Decomposes compound ANSI sequences (e.g., ESC[0;1;33;43m) into
    /// individual sequences (ESC[0m, ESC[1m, ESC[33m, ESC[43m).
    private static func subsplit(_ text: String, result: inout [String]) {
        guard text.count > 3,
              text.hasPrefix(ANSI_INIT),
              text.last == ANSI_END else {
            result.append(text)
            return
        }

        // Extract the inner part (between ESC[ and m)
        let inner = String(text.dropFirst(2).dropLast(1))
        let codes: [String] = inner.split(separator: Character(";"), omittingEmptySubsequences: false)
            .map { $0.isEmpty ? "0" : String($0) }

        var idx = 0
        while idx < codes.count {
            let code = codes[idx]
            idx += 1

            if code == "38" || code == "48" || code == "58" {
                // Extended color sequence - consume additional codes
                var sequence = ANSI_INIT + code

                guard idx < codes.count else {
                    print("parsing ansi control sequence '\(toPrintable(text))'... FAILED")
                    break
                }
                let subCode = codes[idx]
                idx += 1
                sequence += String(ANSI_DELIMITER) + subCode

                if subCode == "2" {
                    // 24-bit: need 3 more values (r, g, b)
                    for _ in 0..<3 {
                        guard idx < codes.count else { break }
                        sequence += String(ANSI_DELIMITER) + codes[idx]
                        idx += 1
                    }
                } else if subCode == "5" {
                    // 8-bit: need 1 more value
                    guard idx < codes.count else { break }
                    sequence += String(ANSI_DELIMITER) + codes[idx]
                    idx += 1
                } else {
                    print("parsing ansi control sequence '\(toPrintable(text))'... FAILED")
                }

                sequence += String(ANSI_END)
                result.append(sequence)
            } else {
                result.append(ANSI_INIT + code + String(ANSI_END))
            }
        }
    }

    // MARK: - Utility

    /// Converts ESC to ^ for printable output (debugging).
    static func toPrintable(_ ansi: String) -> String {
        guard !ansi.isEmpty, ansi.first == ANSI_START else { return ansi }
        return "^" + String(ansi.dropFirst())
    }
}
