import Foundation

public struct TerminalSize: Sendable, Equatable {
    public var height: Int
    public var width: Int
}

extension TerminalSize {
    public static func current() -> Self {
        var w = winsize()
        _ = ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &w)
        return TerminalSize(height: Int(w.ws_row), width: Int(w.ws_col))
    }
}
