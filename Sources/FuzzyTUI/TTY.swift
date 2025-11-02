import Foundation
import TerminalInput

@MainActor
final class TTY {
    let fileHandle: FileHandle
    private var originalTermios: termios?

    init?(fileHandle: FileHandle) {
        guard isatty(fileHandle.fileDescriptor) == 1 else { return nil }
        self.fileHandle = fileHandle
    }

    func setRaw() throws {
        self.originalTermios = try KeyReader.setRaw(fileHandle: self.fileHandle)
    }

    func unsetRaw() throws {
        guard let originalTermios = self.originalTermios else { return }
        try KeyReader.unsetRaw(fileHandle: self.fileHandle, originalTermios: originalTermios)
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
