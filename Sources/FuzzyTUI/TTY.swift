import Foundation

@MainActor
struct TTY {
    private let fileHandle: Int32

    init?(fileHandle: Int32) {
        guard isatty(fileHandle) == 1 else { return nil }
        self.fileHandle = fileHandle
    }

    func withRawMode<T: Sendable>(body: () async throws -> T) async throws -> T {
        var originalTermios = termios()

        if tcgetattr(fileHandle, &originalTermios) == -1 {
            throw Failure.getAttributes
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
            _ = tcsetattr(self.fileHandle, TCSAFLUSH, &originalTermios)
            throw Failure.setAttributes
        }

        let value = try await body()

        if tcsetattr(self.fileHandle, TCSAFLUSH, &originalTermios) < 0 {
            throw Failure.setAttributes
        }

        return value
    }
}

extension TTY {
    enum Failure: Error {
        case getAttributes
        case setAttributes
    }
}
