import AsyncAlgorithms
import Foundation
import Synchronization

@MainActor
func outputCode(_ code: ANSIControlCode) {
    try! FileHandle.standardOutput.write(contentsOf: Data(code.ansiCommand.message.utf8))
    // fdopen() on stdout is fast; also the returned file MUST NOT be fclose()d
    // This avoids concurrency complaints due to accessing global `stdout`.
    fflush(fdopen(STDOUT_FILENO, "w+"))
}

@MainActor
func fillScreen<T>(viewState: ViewState<T>) throws {
    outputCode(.clearScreen)
    let choices = viewState.choices.suffix(viewState.visibleLines.count)
    guard let startLine = viewState.line(forChoiceIndex: viewState.visibleLines.lowerBound) else {
        fatalError()
    }
    for (lineNumber, (index, choice)) in zip(0..., zip(choices.indices, choices)) {
        outputCode(.moveCursor(x: 0, y: startLine + lineNumber))
        print(index == viewState.current ? "> " : "  ", terminator: "")
        print(choice, lineNumber)
    }
    outputCode(.moveBottom(viewState: viewState))
}

@MainActor
func moveUp<T>(viewState: ViewState<T>) {
    guard let current = viewState.current, current > 0 else { return }
    guard let currentLine = viewState.line(forChoiceIndex: current) else {
        debug("moveUp didn't receive line for current \(current)")
        fatalError()
    }

    outputCode(.setCursorHidden(true))
    defer { outputCode(.setCursorHidden(false)) }

    outputCode(.moveCursor(x: 0, y: currentLine))
    print(" ")

    if currentLine > 4 || !viewState.canScrollUp {
        // we don't need to scroll or we can't scroll
        outputCode(.moveCursor(x: 0, y: currentLine - 1))
        print(">")
        viewState.moveUp()
        outputCode(.moveCursor(x: 0, y: viewState.height))
    } else {
        outputCode(.moveToLastLine(viewState: viewState))
        outputCode(.clearLine)
        outputCode(.moveCursor(x: 0, y: 0))
        outputCode(.insertLines(1))
        viewState.moveUp()
        viewState.scrollUp()

        print("  ", viewState.choices[viewState.visibleLines.lowerBound], separator: "")
        guard let newCurrentLine = viewState.line(forChoiceIndex: current - 1) else { fatalError() }
        outputCode(.moveCursor(x: 0, y: newCurrentLine))
        print("> ", separator: "")
        outputCode(.moveCursor(x: 0, y: viewState.height))
        outputCode(.clearLine)
    }
}

@MainActor
func moveDown<T>(viewState: ViewState<T>) {
    guard let current = viewState.current, current < viewState.choices.count - 1 else { return }
    guard let currentLine = viewState.line(forChoiceIndex: current) else {
        fatalError()
    }

    outputCode(.setCursorHidden(true))
    defer { outputCode(.setCursorHidden(false)) }

    outputCode(.moveCursor(x: 0, y: currentLine))
    print("  ")

    if currentLine < viewState.height - 4 || !viewState.canScrollDown {
        outputCode(.moveCursor(x: 0, y: currentLine + 1))
        print(">")
        viewState.moveDown()
        outputCode(.moveBottom(viewState: viewState))
    } else {
        outputCode(.moveCursor(x: 0, y: 0))
        outputCode(.clearLine)
        outputCode(.moveToLastLine(viewState: viewState))

        viewState.moveDown()
        viewState.scrollDown()

        print("  ", viewState.choices[viewState.visibleLines.upperBound], separator: "")

        guard let newCurrentLine = viewState.line(forChoiceIndex: current + 1) else { fatalError() }

        outputCode(.moveCursor(x: 0, y: newCurrentLine))
        print("> ")

        outputCode(.moveBottom(viewState: viewState))
    }
}

@MainActor
final class KeyReader {
    private let queue: DispatchQueue
    private let stopped: Mutex<Bool> = .init(false)
    private let tty: TTY

    init(tty: TTY) {
        self.queue = DispatchQueue(label: "fi.juripakaste.swiftfzf.keyReader")
        self.tty = tty
    }

    func readKeys(to callback: @escaping @Sendable (Result<TerminalKey?, any Error>) -> Void) {
        self.queue.async {
            while !self.stopped.withLock({ $0 }) {
                do {
                    let key = try self.tty.withRawMode { () -> TerminalKey? in
                        var buffer = [UInt8](repeating: 0, count: 3)
                        let bytesRead = read(STDIN_FILENO, &buffer, 3)
                        debug("bytesRead: \(bytesRead), buffer: \(buffer)")
                        if bytesRead == 1 && buffer[0] == 0x03 {
                            return .terminate
                        }
                        if bytesRead == 3 && buffer[0] == 0x1B && buffer[1] == 0x5B {
                            switch buffer[2] {
                            case 0x41: return .up
                            case 0x42: return .down
                            default: return nil
                            }
                        }
                        return nil
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

enum Event<T: CustomStringConvertible & Sendable> {
    case key(TerminalKey?)
    case choice(T)
    case viewStateChanged
}

@MainActor
func runSelector<T: CustomStringConvertible & Sendable, E: Error>(
    choices: some AsyncSequence<T, E> & Sendable
) async throws -> [T] {
    let terminalSize = TerminalSize.current()
    debug("----------------------------------------", reset: true)
    debug("Terminal height: \(terminalSize.height)")
    guard let tty = TTY(fileHandle: STDIN_FILENO) else {
        // TODO: error
        return []
    }

    let viewState = ViewState(
        choices: [T](),
        height: terminalSize.height,
        maxWidth: terminalSize.width - 3
    )

    debug("Visible lines: \(viewState.visibleLines)")
    try fillScreen(viewState: viewState)

    let keyReader = KeyReader(tty: tty)
    let keyEvents = keyReader.keys
        .map { keyResult throws -> Event<T> in
            switch keyResult {
            case let .success(key): return Event.key(key)
            case let .failure(error): throw error
            }
        }
    let viewStateUpdateEvents = viewState.changed
        .map { Event<T>.viewStateChanged }

    let choiceEvents = choices
        .map { choice -> Event<T> in .choice(choice) }

    eventLoop: for try await event in merge(keyEvents, choiceEvents, viewStateUpdateEvents) {
        debug("got event: \(event)")
        switch event {
        case .key(.down): moveDown(viewState: viewState)
        case .key(.up): moveUp(viewState: viewState)
        case .key(.terminate): break eventLoop
        case .key(nil): break
        case let .choice(choice):
            viewState.addChoice(choice)
            try fillScreen(viewState: viewState)
        case .viewStateChanged:
            try fillScreen(viewState: viewState)
        }
    }

    return []
}

@main
@MainActor
struct Fzf {
    static func main() async throws -> Void {
        let choices = AsyncStream(unfolding: {
            try! await Task.sleep(for: .seconds(1.5))
            return "line \(Date())"
        })

        _ = try await runSelector(choices: choices)
    }
}

private func debug(_ message: String, reset: Bool = false) {
    let fh = FileHandle(forUpdatingAtPath: "/tmp/swiftfzfdebug.log")!
    if reset {
        try! fh.truncate(atOffset: 0)
    }
    if message.isEmpty { return }

    try! fh.seekToEnd()
    try! fh.write(contentsOf: Data(message.utf8))
    try! fh.write(contentsOf: Data("\n".utf8))
    try! fh.close()
}
