import Foundation

struct TTY {
    private let fileHandle: Int32

    init?(fileHandle: Int32) {
        guard isatty(fileHandle) == 1 else { return nil }
        self.fileHandle = fileHandle
    }

    func withRawMode<T>(body: () throws -> T) throws -> T {
        var originalTermios = termios()

        if tcgetattr(fileHandle, &originalTermios) == -1 {
            throw Failure.getAttributes
        }

        defer {
            // TODO: This doesn't seem to do the trick? ctrl-z doesn't work after this
            _ = tcsetattr(self.fileHandle, TCSAFLUSH, &originalTermios)
        }

        var raw = originalTermios

        raw.c_iflag &= ~tcflag_t(BRKINT | ICRNL | INPCK | ISTRIP | IXON)
        raw.c_oflag &= ~tcflag_t(OPOST)
        raw.c_cflag |= tcflag_t(CS8)
        raw.c_lflag &= ~tcflag_t(ECHO | ICANON | IEXTEN | ISIG)

        withUnsafeMutablePointer(to: &raw.c_cc) {
            $0.withMemoryRebound(to: cc_t.self, capacity: Int(NCCS)) { $0[Int(VMIN)] = 1 }
        }

        if tcsetattr(fileHandle, TCSAFLUSH, &raw) < 0 {
            throw Failure.setAttributes
        }

        return try body()
    }
}

extension TTY {
    enum Failure: Error {
        case getAttributes
        case setAttributes
    }
}
