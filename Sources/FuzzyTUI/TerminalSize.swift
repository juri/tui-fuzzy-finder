import Foundation

/// `TerminalSize` is represents the size of the terminal running the selector.
///
/// You can get the current size with the static ``current()`` method.
public struct TerminalSize: Sendable, Equatable {
    public var height: Int
    public var width: Int
}

extension TerminalSize {
    /// Return the current terminal size.
    public static func current() -> Self {
        var w = winsize()
        _ = ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &w)
        return TerminalSize(height: Int(w.ws_row), width: Int(w.ws_col))
    }
}
