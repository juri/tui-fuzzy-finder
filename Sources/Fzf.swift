import AsyncAlgorithms
import Foundation

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
func choiceMarker<T>(choiceItem: FilteredChoiceItem<T>, viewState: ViewState<T>) -> String {
    let isSelected = viewState.isSelected(choiceItem)
    let selectionMarker = isSelected ? "+" : " "
    return selectionMarker
}

@MainActor
func fillScreen<T>(viewState: ViewState<T>) {
    outputCode(.clearScreen)

    let choices = viewState.choices.suffix(viewState.visibleLines.count)
    guard let startLine = viewState.line(forChoiceIndex: viewState.visibleLines.lowerBound) else {
        fatalError()
    }
    for (lineNumber, (index, choiceItem)) in zip(0..., zip(choices.indices, choices)) {
        outputCode(.moveCursor(x: 0, y: startLine + lineNumber))
        let selectionMarker = choiceMarker(choiceItem: choiceItem, viewState: viewState)
        print(index == viewState.current ? ">\(selectionMarker)" : " \(selectionMarker)", terminator: "")
        print(choiceItem.choice, lineNumber)
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
    for (lineNumber, (index, choiceItem)) in zip(0..., zip(choices.indices, choices)) {
        outputCode(.moveCursor(x: 0, y: startLine + lineNumber))
        let selectionMarker = choiceMarker(choiceItem: choiceItem, viewState: viewState)
        print(index == viewState.current ? ">\(selectionMarker)" : " \(selectionMarker)", terminator: "")
        print(choiceItem.choice, lineNumber)
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

        let choiceItem = viewState.choices[viewState.visibleLines.lowerBound]
        let selectionMarker = choiceMarker(choiceItem: choiceItem, viewState: viewState)
        print(" \(selectionMarker)", choiceItem.choice, separator: "")
        guard let newCurrentLine = viewState.line(forChoiceIndex: current - 1) else { fatalError() }
        outputCodes([
            .moveCursor(x: 0, y: newCurrentLine),
            .literal(">"),
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
        .literal(" "),
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

        let choiceItem = viewState.choices[viewState.visibleLines.upperBound]
        let selectionMarker = choiceMarker(choiceItem: choiceItem, viewState: viewState)
        print(" \(selectionMarker)", choiceItem.choice, separator: "")

        guard let newCurrentLine = viewState.line(forChoiceIndex: current + 1) else { fatalError() }

        outputCodes([
            .moveCursor(x: 0, y: newCurrentLine),
            .literal(">"),
            .moveBottom(viewState: viewState),
        ])
    }
}

@MainActor
func showFilter<T>(viewState: ViewState<T>) {
    outputCodes([
        .moveBottom(viewState: viewState),
        .clearLine,
        .literal(viewState.filter),
        .moveCursorToColumn(n: viewState.editPosition + 1),
    ])
}

enum Event<T: CustomStringConvertible & Sendable> {
    case key(TerminalKey?)
    case choice(T)
    case viewStateChanged
}

@MainActor
func runSelector<T: CustomStringConvertible & Sendable & Equatable, E: Error>(
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
        case .key(.backspace):
            viewState.editFilter(.backspace)
            showFilter(viewState: viewState)
        case let .key(.character(character)):
            viewState.editFilter(.insert(character))
            showFilter(viewState: viewState)
        case .key(.delete):
            viewState.editFilter(.delete)
            showFilter(viewState: viewState)
        case .key(.deleteToEnd):
            viewState.editFilter(.deleteToEnd)
            showFilter(viewState: viewState)
        case .key(.deleteToStart):
            viewState.editFilter(.deleteToStart)
            showFilter(viewState: viewState)
        case .key(.down):
            withSavedCursorPosition {
                moveDown(viewState: viewState)
            }
        case .key(.tab):
            viewState.toggleCurrentSelection()
            withSavedCursorPosition {
                redrawChoices(viewState: viewState)
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
        case .key(.some(.left)):
            viewState.editFilter(.left)
            showFilter(viewState: viewState)
        case .key(.some(.right)):
            viewState.editFilter(.right)
            showFilter(viewState: viewState)
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

func debug(_ message: String, reset: Bool = false) {
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
