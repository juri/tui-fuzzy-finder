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
            var buffer = [UInt8](repeating: 0, count: 4)
            var bufferPoint = 0
            loop: while !self.stopped.withLock({ $0 }) {
                let key: TerminalKey?
                if bufferPoint < 4 {
                    var inputBuffer = [UInt8](repeating: 0, count: 4 - bufferPoint)
                    let bytesRead = read(self.tty.fileHandle.fileDescriptor, &inputBuffer, 4 - bufferPoint)
                    for byteIndex in 0..<bytesRead {
                        let byte = inputBuffer[byteIndex]
                        let targetIndex = bufferPoint + byteIndex
                        buffer[targetIndex] = byte
                    }
                    bufferPoint += bytesRead
                }

                guard bufferPoint > 0 else {
                    continue loop
                }
                if bufferPoint == 1 {
                    switch buffer[0] {
                    case 0x01: key = .moveToStart
                    case 0x03: key = .terminate
                    case 0x04: key = .delete
                    case 0x05: key = .moveToEnd
                    case 0x09: key = .tab
                    case 0x0B: key = .deleteToEnd
                    case 0x0D: key = .return
                    case 0x14: key = .transpose
                    case 0x15: key = .deleteToStart
                    case 0x1A: key = .suspend
                    case 0x7F: key = .backspace
                    default: key = .character(Character(.init(buffer[0])))
                    }
                    consumeStart(array: &buffer, bytes: 1)
                    bufferPoint -= 1
                } else if bufferPoint >= 3 {
                    switch (buffer[0], buffer[1], buffer[2]) {
                    case (0x1B, 0x5B, 0x41): key = .up
                    case (0x1B, 0x5B, 0x42): key = .down
                    case (0x1B, 0x5B, 0x43): key = .right
                    case (0x1B, 0x5B, 0x44): key = .left
                    default: continue loop
                    }
                    consumeStart(array: &buffer, bytes: 3)
                    bufferPoint -= 3
                } else if var str = String(bytes: buffer[0..<bufferPoint], encoding: .utf8),
                    str.count > 0
                {
                    let first = str.removeFirst()
                    let count = first.utf8.count
                    consumeStart(array: &buffer, bytes: count)
                    bufferPoint -= count
                    key = .character(first)
                } else if bufferPoint == 4 {
                    // buffer is already full, and we apparently didn't know what to do with it.
                    buffer[0] = 0
                    buffer[1] = 0
                    buffer[2] = 0
                    buffer[3] = 0
                    bufferPoint = 0
                    key = nil
                } else {
                    key = nil
                }

                callback(.success(key))
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

private func consumeStart(array: inout [UInt8], bytes: Int) {
    if bytes > 0 && bytes < array.count {
        array.withUnsafeMutableBufferPointer { buffer in
            let src = buffer.baseAddress! + bytes
            let dst = buffer.baseAddress!
            let count = buffer.count - bytes

            // Move remaining bytes to the front
            dst.moveInitialize(from: src, count: count)

            // Zero out the end
            (dst + count).initialize(repeating: 0, count: bytes)
        }
    }
}
