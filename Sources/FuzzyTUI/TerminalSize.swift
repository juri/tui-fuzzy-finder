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
    public static func current() -> Self? {
        var w = winsize()
        guard let tty = FileHandle.init(forReadingAtPath: "/dev/tty") else { return nil }
        _ = ioctl(tty.fileDescriptor, UInt(TIOCGWINSZ), &w)
        return TerminalSize(height: Int(w.ws_row), width: Int(w.ws_col))
    }
}
