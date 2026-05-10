/// A simple pair of integers used for positions and dimensions.
/// Mirrors the C++ `IntPair` union where `x` aliases `w` and `y` aliases `h`.
public struct IntPair {
    var x: Int
    var y: Int

    var w: Int {
        get { return x }
        set { x = newValue }
    }
    var h: Int {
        get { return y }
        set { y = newValue }
    }

    init(x: Int = 0, y: Int = 0) {
        self.x = x
        self.y = y
    }

    init(w: Int, h: Int) {
        self.x = w
        self.y = h
    }
}

typealias Position = IntPair
typealias Dimension = IntPair
