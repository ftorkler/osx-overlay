public struct Color: Equatable {
    var r: UInt8
    var g: UInt8
    var b: UInt8
    var a: UInt8

    init(_ r: UInt8 = 255, _ g: UInt8 = 255, _ b: UInt8 = 255, _ a: UInt8 = 255) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    init(_ r: Int, _ g: Int, _ b: Int, _ a: Int) {
        self.r = UInt8(clamping: r)
        self.g = UInt8(clamping: g)
        self.b = UInt8(clamping: b)
        self.a = UInt8(clamping: a)
    }

    static let unset = Color(UInt8(255), UInt8(255), UInt8(255), UInt8(255))

    /// Sentinel value used to detect "not yet configured" state in Config
    static let configUnset = Color(Int(-1), Int(-1), Int(-1), Int(-1))
}
