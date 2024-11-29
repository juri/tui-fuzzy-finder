import Foundation

@MainActor
final class TTY {
    let fileHandle: FileHandle
    private var originalTermios: termios?

    init?(fileHandle: FileHandle) {
        guard isatty(fileHandle.fileDescriptor) == 1 else { return nil }
        self.fileHandle = fileHandle
    }

    func setRaw() throws {
        var originalTermios = termios()

        if tcgetattr(fileHandle.fileDescriptor, &originalTermios) == -1 {
            throw Failure.getAttributes
        }

        self.originalTermios = originalTermios
        var raw = originalTermios

        raw.c_iflag &= ~tcflag_t(BRKINT | ICRNL | INPCK | ISTRIP | IXON)
        raw.c_oflag &= ~tcflag_t(OPOST)
        raw.c_cflag |= tcflag_t(CS8)
        raw.c_lflag &= ~tcflag_t(ECHO | ICANON | IEXTEN | ISIG)

        withUnsafeMutablePointer(to: &raw.c_cc) {
            $0.withMemoryRebound(to: cc_t.self, capacity: Int(NCCS)) { $0[Int(VMIN)] = 1 }
        }

        if tcsetattr(self.fileHandle.fileDescriptor, TCSAFLUSH, &raw) < 0 {
            throw Failure.setAttributes
        }
    }

    func unsetRaw() throws {
        guard var originalTermios = self.originalTermios else { return }
        if tcsetattr(self.fileHandle.fileDescriptor, TCSAFLUSH, &originalTermios) < 0 {
            throw Failure.setAttributes
        }
    }
}

extension TTY {
    enum Failure: Error {
        case getAttributes
        case setAttributes
    }
}

@MainActor
final class OutTTY {
    private let fileHandle: FileHandle

    init?(fileHandle: FileHandle) {
        guard isatty(fileHandle.fileDescriptor) == 1 else { return nil }
        self.fileHandle = fileHandle
    }

    func close() throws {
        try self.fileHandle.synchronize()
        tcflush(self.fileHandle.fileDescriptor, TCOFLUSH)
        try self.fileHandle.close()
    }

    func write(_ strings: [String]) {
        for string in strings {
            try! self.fileHandle.write(contentsOf: Data(string.utf8))
        }
        try! self.fileHandle.synchronize()
    }
}
