import AsyncAlgorithms
import Foundation
import Synchronization

@MainActor
func write(_ strings: [String]) {
    for string in strings {
        try! FileHandle.standardOutput.write(contentsOf: Data(string.utf8))
    }
    try! FileHandle.standardOutput.synchronize()
}

@MainActor
func write(_ string: String) {
    write([string])
}

@MainActor
func outputCode(_ code: ANSIControlCode) {
    write(code.ansiCommand.message)
}

@MainActor
func outputCodes(_ codes: [ANSIControlCode]) {
    write(codes.map(\.ansiCommand.message))
}

@MainActor
func withSavedCursorPosition<T>(_ body: () throws -> T) rethrows -> T {
    outputCodes([
        .setCursorHidden(true),
        .saveCursorPosition,
    ])
    defer {
        outputCodes([
            .restoreCursorPosition,
            .setCursorHidden(false),
        ])
    }

    return try body()
}

@MainActor
func fillScreen<T>(viewState: ViewState<T>) {
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
    showFilter(viewState: viewState)
}

@MainActor
func redrawChoices<T>(viewState: ViewState<T>) {
    outputCode(.moveCursor(x: 0, y: 0))
    outputCode(.clearLine)
    for _ in 0..<viewState.height - 2 {
        outputCode(.moveCursorDown(n: 1))
        outputCode(.clearLine)
    }

    let choices = viewState.choices.suffix(viewState.visibleLines.count)
    guard let startLine = viewState.line(forChoiceIndex: viewState.visibleLines.lowerBound) else {
        fatalError()
    }
    for (lineNumber, (index, choice)) in zip(0..., zip(choices.indices, choices)) {
        outputCode(.moveCursor(x: 0, y: startLine + lineNumber))
        print(index == viewState.current ? "> " : "  ", terminator: "")
        print(choice, lineNumber)
    }
}

@MainActor
func moveUp<T>(viewState: ViewState<T>) {
    guard let current = viewState.current, current > 0 else { return }
    guard let currentLine = viewState.line(forChoiceIndex: current) else {
        debug("moveUp didn't receive line for current \(current)")
        fatalError()
    }

    outputCodes([
        .moveCursor(x: 0, y: currentLine),
        .literal(" "),
    ])

    if currentLine > 4 || !viewState.canScrollUp {
        // we don't need to scroll or we can't scroll
        outputCodes([
            .moveCursor(x: 0, y: currentLine - 1),
            .literal(">"),
            .moveCursor(x: 0, y: viewState.height),
        ])
        viewState.moveUp()
    } else {
        outputCodes([
            .moveToLastLine(viewState: viewState),
            .clearLine,
            .moveCursor(x: 0, y: 0),
            .insertLines(1),
        ])
        viewState.moveUp()
        viewState.scrollUp()

        print("  ", viewState.choices[viewState.visibleLines.lowerBound], separator: "")
        guard let newCurrentLine = viewState.line(forChoiceIndex: current - 1) else { fatalError() }
        outputCodes([
            .moveCursor(x: 0, y: newCurrentLine),
            .literal("> "),
            .moveCursor(x: 0, y: viewState.height),
            .clearLine,
        ])
    }
}

@MainActor
func moveDown<T>(viewState: ViewState<T>) {
    guard let current = viewState.current, current < viewState.choices.count - 1 else { return }
    guard let currentLine = viewState.line(forChoiceIndex: current) else {
        fatalError()
    }

    outputCodes([
        .moveCursor(x: 0, y: currentLine),
        .literal("  "),
    ])

    if currentLine < viewState.height - 4 || !viewState.canScrollDown {
        outputCodes([
            .moveCursor(x: 0, y: currentLine + 1),
            .literal(">"),
        ])
        viewState.moveDown()
        outputCode(.moveBottom(viewState: viewState))
    } else {
        outputCodes([
            .moveCursor(x: 0, y: 0),
            .clearLine,
            .moveToLastLine(viewState: viewState),
            .scrollUp(1),
        ])

        viewState.moveDown()
        viewState.scrollDown()

        print("  ", viewState.choices[viewState.visibleLines.upperBound], separator: "")

        guard let newCurrentLine = viewState.line(forChoiceIndex: current + 1) else { fatalError() }

        outputCodes([
            .moveCursor(x: 0, y: newCurrentLine),
            .literal("> "),
            .moveBottom(viewState: viewState),
        ])
    }
}

@MainActor
func showFilter<T>(viewState: ViewState<T>) {
    outputCodes([
        .moveBottom(viewState: viewState),
        .clearLine,
    ])
    write(viewState.filter)
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
                        if bytesRead == 1 {
                            if buffer[0] == 0x03 {
                                return .terminate
                            }
                            let char = Character(.init(buffer[0]))
                            return .character(char)
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
    fillScreen(viewState: viewState)

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

    let choiceEvents = choices.map { choice -> Event<T> in .choice(choice) }

    eventLoop: for try await event in merge(keyEvents, choiceEvents, viewStateUpdateEvents) {
        debug("got event: \(event)")
        switch event {
        case let .key(.character(character)):
            viewState.addToFilter(character)
            showFilter(viewState: viewState)
        case .key(.down):
            withSavedCursorPosition {
                moveDown(viewState: viewState)
            }
        case .key(.up):
            withSavedCursorPosition {
                moveUp(viewState: viewState)
            }
        case .key(.terminate): break eventLoop
        case .key(nil): break
        case let .choice(choice):
            viewState.addChoice(choice)
            withSavedCursorPosition {
                redrawChoices(viewState: viewState)
            }
        case .viewStateChanged:
            withSavedCursorPosition {
                redrawChoices(viewState: viewState)
            }
        }
    }

    return []
}

@main
@MainActor
struct Fzf {
    static func main() async throws {
        let choices = AsyncStream(unfolding: {
            try! await Task.sleep(for: .seconds(1))
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
