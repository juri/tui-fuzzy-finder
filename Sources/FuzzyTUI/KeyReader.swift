import Foundation
import Synchronization

@MainActor
final class KeyReader {
    private let queue: DispatchQueue
    private let stopped: Mutex<Bool> = .init(false)
    private let tty: TTY

    init(tty: TTY) {
        self.queue = DispatchQueue(label: "fuzzytui.keyReader")
        self.tty = tty
    }

    func readKeys(to callback: @escaping @Sendable (Result<TerminalKey?, any Error>) -> Void) {
        self.queue.async {
            while !self.stopped.withLock({ $0 }) {
                do {
                    let key = try self.tty.withRawMode { () -> TerminalKey? in
                        var buffer = [UInt8](repeating: 0, count: 4)
                        let bytesRead = read(STDIN_FILENO, &buffer, 4)
                        debug("bytesRead: \(bytesRead), buffer: \(buffer)")
                        if bytesRead == 1 {
                            switch buffer[0] {
                            case 0x01: return .moveToStart
                            case 0x03: return .terminate
                            case 0x04: return .delete
                            case 0x05: return .moveToEnd
                            case 0x09: return .tab
                            case 0x0B: return .deleteToEnd
                            case 0x14: return .transpose
                            case 0x15: return .deleteToStart
                            case 0x7F: return .backspace
                            default: return .character(Character(.init(buffer[0])))
                            }
                        }
                        if bytesRead == 3 {
                            switch (buffer[0], buffer[1], buffer[2]) {
                            case (0x1B, 0x5B, 0x41): return .up
                            case (0x1B, 0x5B, 0x42): return .down
                            case (0x1B, 0x5B, 0x43): return .right
                            case (0x1B, 0x5B, 0x44): return .left
                            default: break
                            }
                        }
                        guard let character = toCharacter(bytes: buffer[0..<bytesRead]) else {
                            return nil
                        }
                        return .character(character)
                    }
                    callback(.success(key))
                } catch {
                    callback(.failure(error))
                }
            }
        }
    }

    var keys: AsyncStream<Result<TerminalKey?, any Error>> {
        return AsyncStream<Result<TerminalKey?, any Error>> { continuation in
            continuation.onTermination = { _ in
                self.stopped.withLock { $0 = true }
            }
            self.readKeys { result in
                continuation.yield(result)
            }
        }
    }
}

func toCharacter(bytes: ArraySlice<UInt8>) -> Character? {
    guard let str = String(bytes: bytes, encoding: .utf8) else { return nil }
    return Character(str)
}
