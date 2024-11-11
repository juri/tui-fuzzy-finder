import AsyncAlgorithms
import Foundation

public typealias Selectable = CustomStringConvertible & Sendable & Equatable

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
func fillScreen<T>(
    appearance: Appearance,
    viewState: ViewState<T>
) {
    outputCode(.clearScreen)

    let choices = viewState.choices.suffix(viewState.visibleLines.count)
    guard let startLine = viewState.line(forChoiceIndex: viewState.visibleLines.lowerBound) else {
        fatalError()
    }
    var codes = [ANSIControlCode]()
    for (lineNumber, (index, choiceItem)) in zip(0..., zip(choices.indices, choices)) {
        codes.append(.moveCursor(x: 0, y: startLine + lineNumber))
        let scroller = scroller(appearance: appearance, viewState: viewState, choiceItem: choiceItem, index: index)
        addScrollerCodes(into: &codes, scroller: scroller)
        codes.append(.setGraphicsRendition([.reset]))
        let textAttrs = textAttributes(
            appearance: appearance,
            viewState: viewState,
            choiceItem: choiceItem,
            index: index
        )
        codes.append(.setGraphicsRendition(setGraphicsModes(textAttributes: textAttrs)))
        codes.append(.literal(String(describing: choiceItem.choice)))
    }
    codes.append(.moveBottom(viewState: viewState))
    outputCodes(codes)
    showFilter(viewState: viewState)
}

func setGraphicsModes(textAttributes: Set<Appearance.TextAttributes>) -> [SetGraphicsRendition] {
    textAttributes.map { attr in
        switch attr {
        case let .background(.basic(p)):
            return .backgroundBasic(p)
        case let .background(.basicBright(p)):
            return .backgroundBasicBright(p)
        case let .background(.palette256(v)):
            return .background256(v)
        case let .background(.rgb(red: r, green: g, blue: b)):
            return .backgroundRGB(red: r, green: g, blue: b)
        case .bold:
            return .bold
        case let .foreground(.basic(p)):
            return .textBasic(p)
        case let .foreground(.basicBright(p)):
            return .textBasicBright(p)
        case let .foreground(.palette256(v)):
            return .text256(v)
        case let .foreground(.rgb(red: r, green: g, blue: b)):
            return .textRGB(red: r, green: g, blue: b)
        case .italic:
            return .italic
        case .underline:
            return .underline
        }
    }
}

@MainActor
func scroller<T>(
    appearance: Appearance,
    viewState: ViewState<T>,
    choiceItem: FilteredChoiceItem<T>,
    index: Int
) -> Appearance.Scroller {
    scroller(
        appearance: appearance,
        viewState: viewState,
        choiceItem: choiceItem,
        isActive: index == viewState.current
    )
}

@MainActor
func scroller<T>(
    appearance: Appearance,
    viewState: ViewState<T>,
    choiceItem: FilteredChoiceItem<T>,
    isActive: Bool
) -> Appearance.Scroller {
    switch (isActive, viewState.isSelected(choiceItem)) {
    case (false, false): return appearance.inactiveScroller
    case (false, true): return appearance.selectedScroller
    case (true, false): return appearance.highlightedScroller
    case (true, true): return appearance.highlightedSelectedScroller
    }
}

@MainActor
func textAttributes<T>(
    appearance: Appearance,
    viewState: ViewState<T>,
    choiceItem: FilteredChoiceItem<T>,
    index: Int
) -> Set<Appearance.TextAttributes> {
    textAttributes(
        appearance: appearance,
        viewState: viewState,
        choiceItem: choiceItem,
        isActive: index == viewState.current
    )
}

@MainActor
func textAttributes<T>(
    appearance: Appearance,
    viewState: ViewState<T>,
    choiceItem: FilteredChoiceItem<T>,
    isActive: Bool
) -> Set<Appearance.TextAttributes> {
    switch (isActive, viewState.isSelected(choiceItem)) {
    case (false, false): return appearance.inactiveTextAttributes
    case (false, true): return appearance.selectedTextAttributes
    case (true, false): return appearance.highlightedTextAttributes
    case (true, true): return appearance.highlightedTextAttributes
    }
}

@MainActor
func redrawChoices<T>(
    appearance: Appearance,
    viewState: ViewState<T>
) {
    var codes = [ANSIControlCode]()
    codes.append(.moveCursor(x: 0, y: 0))
    codes.append(.clearLine)

    for _ in 0..<viewState.height - 2 {
        codes.append(.moveCursorDown(n: 1))
        codes.append(.clearLine)
    }

    let choices = viewState.choices.suffix(viewState.visibleLines.count)
    guard let startLine = viewState.line(forChoiceIndex: viewState.visibleLines.lowerBound) else {
        fatalError()
    }
    for (lineNumber, (index, choiceItem)) in zip(0..., zip(choices.indices, choices)) {
        codes.append(.moveCursor(x: 0, y: startLine + lineNumber))

        let scroller = scroller(appearance: appearance, viewState: viewState, choiceItem: choiceItem, index: index)
        addScrollerCodes(into: &codes, scroller: scroller)
        codes.append(.setGraphicsRendition([.reset]))
        let textAttrs = textAttributes(
            appearance: appearance,
            viewState: viewState,
            choiceItem: choiceItem,
            index: index
        )
        codes.append(.setGraphicsRendition(setGraphicsModes(textAttributes: textAttrs)))
        codes.append(.literal(String(describing: choiceItem.choice)))
    }
    outputCodes(codes)
}

func addScrollerCodes(into codes: inout [ANSIControlCode], scroller: Appearance.Scroller) {
    for textItem in scroller.text {
        let sgr = setGraphicsModes(textAttributes: textItem.attributes)
        codes.append(.setGraphicsRendition([.reset]))
        codes.append(.setGraphicsRendition(sgr))
        codes.append(.literal(textItem.text))
    }
}

@MainActor
func moveUp<T>(
    appearance: Appearance,
    viewState: ViewState<T>
) {
    guard let current = viewState.current, current > 0 else { return }
    guard let currentLine = viewState.line(forChoiceIndex: current) else {
        debug("moveUp didn't receive line for current \(current)")
        fatalError()
    }
    var codes = [ANSIControlCode]()
    codes.append(.moveCursor(x: 0, y: currentLine))

    do {
        // clean up previous line
        let oldItem = viewState.choices[current]
        addScrollerCodes(into: &codes, scroller: scroller(
            appearance: appearance,
            viewState: viewState,
            choiceItem: oldItem,
            isActive: false
        ))
        codes.append(.setGraphicsRendition([.reset]))
        let textAttrs = textAttributes(
            appearance: appearance,
            viewState: viewState,
            choiceItem: oldItem,
            isActive: false
        )
        codes.append(.setGraphicsRendition(setGraphicsModes(textAttributes: textAttrs)))
        codes.append(.literal(String(describing: oldItem.choice)))
    }

    if currentLine > 4 || !viewState.canScrollUp {
        // we don't need to scroll or we can't scroll
        codes.append(.moveCursor(x: 0, y: currentLine - 1))
        viewState.moveUp()
        let newItem = viewState.choices[current - 1]
        addScrollerCodes(into: &codes, scroller: scroller(
            appearance: appearance,
            viewState: viewState,
            choiceItem: newItem,
            isActive: true
        ))

        codes.append(.setGraphicsRendition([.reset]))
        let textAttrs = textAttributes(
            appearance: appearance,
            viewState: viewState,
            choiceItem: newItem,
            isActive: true
        )
        codes.append(.setGraphicsRendition(setGraphicsModes(textAttributes: textAttrs)))
        codes.append(.literal(String(describing: newItem.choice)))

        codes.append(.moveCursor(x: 0, y: viewState.height))
    } else {
        codes.append(.moveToLastLine(viewState: viewState))
        codes.append(.clearLine)
        codes.append(.moveCursor(x: 0, y: 0))
        codes.append(.insertLines(1))

        viewState.moveUp()
        viewState.scrollUp()

        do {
            let newTopmostItem = viewState.choices[viewState.visibleLines.lowerBound]

            codes.append(.clearLine)

            addScrollerCodes(into: &codes, scroller: scroller(
                appearance: appearance,
                viewState: viewState,
                choiceItem: newTopmostItem,
                isActive: false
            ))

            codes.append(.setGraphicsRendition([.reset]))
            let textAttrs = textAttributes(
                appearance: appearance,
                viewState: viewState,
                choiceItem: newTopmostItem,
                isActive: false
            )
            codes.append(.setGraphicsRendition(setGraphicsModes(textAttributes: textAttrs)))
            codes.append(.literal(String(describing: newTopmostItem.choice)))
        }

        guard let newCurrentLine = viewState.line(forChoiceIndex: current - 1) else { fatalError() }
        codes.append(.moveCursor(x: 0, y: newCurrentLine))
        do {
            let newChoiceItem = viewState.choices[current - 1]
            addScrollerCodes(into: &codes, scroller: scroller(
                appearance: appearance,
                viewState: viewState,
                choiceItem: newChoiceItem,
                isActive: true
            ))
            let textAttrs = textAttributes(
                appearance: appearance,
                viewState: viewState,
                choiceItem: newChoiceItem,
                isActive: true
            )
            codes.append(.setGraphicsRendition(setGraphicsModes(textAttributes: textAttrs)))
            codes.append(.literal(String(describing: newChoiceItem.choice)))
        }

        codes.append(.moveCursor(x: 0, y: viewState.height))
        codes.append(.clearLine)
    }
    outputCodes(codes)
}

@MainActor
func moveDown<T>(
    appearance: Appearance,
    viewState: ViewState<T>
) {
    guard let current = viewState.current, current < viewState.choices.count - 1 else { return }
    guard let currentLine = viewState.line(forChoiceIndex: current) else {
        fatalError()
    }

    var codes = [ANSIControlCode]()
    codes.append(.moveCursor(x: 0, y: currentLine))

    do {
        // clean up previous line
        let oldItem = viewState.choices[current]
        addScrollerCodes(into: &codes, scroller: scroller(
            appearance: appearance,
            viewState: viewState,
            choiceItem: oldItem,
            isActive: false
        ))
        codes.append(.setGraphicsRendition([.reset]))
        let textAttrs = textAttributes(
            appearance: appearance,
            viewState: viewState,
            choiceItem: oldItem,
            isActive: false
        )
        codes.append(.setGraphicsRendition(setGraphicsModes(textAttributes: textAttrs)))
        codes.append(.literal(String(describing: oldItem.choice)))
    }


    if currentLine < viewState.height - 4 || !viewState.canScrollDown {
        // we don't need to scroll or we can't scroll
        codes.append(.moveCursor(x: 0, y: currentLine + 1))
        viewState.moveDown()
        let newItem = viewState.choices[current + 1]
        addScrollerCodes(into: &codes, scroller: scroller(
            appearance: appearance,
            viewState: viewState,
            choiceItem: newItem,
            isActive: true
        ))

        codes.append(.setGraphicsRendition([.reset]))
        let textAttrs = textAttributes(
            appearance: appearance,
            viewState: viewState,
            choiceItem: newItem,
            isActive: true
        )
        codes.append(.setGraphicsRendition(setGraphicsModes(textAttributes: textAttrs)))
        codes.append(.literal(String(describing: newItem.choice)))

        outputCode(.moveBottom(viewState: viewState))
    } else {
        codes.append(.moveCursor(x: 0, y: 0))
        codes.append(.clearLine)
        codes.append(.moveToLastLine(viewState: viewState))
        codes.append(.scrollUp(1))

        viewState.moveDown()
        viewState.scrollDown()

        do {
            let newBottommostItem = viewState.choices[viewState.visibleLines.upperBound]
            codes.append(.clearLine)
            addScrollerCodes(into: &codes, scroller: scroller(
                appearance: appearance,
                viewState: viewState,
                choiceItem: newBottommostItem,
                isActive: false
            ))
            codes.append(.setGraphicsRendition([.reset]))
            let textAttrs = textAttributes(
                appearance: appearance,
                viewState: viewState,
                choiceItem: newBottommostItem,
                isActive: false
            )
            codes.append(.setGraphicsRendition(setGraphicsModes(textAttributes: textAttrs)))
            codes.append(.literal(String(describing: newBottommostItem.choice)))
        }

        guard let newCurrentLine = viewState.line(forChoiceIndex: current + 1) else { fatalError() }

        codes.append(.moveCursor(x: 0, y: newCurrentLine))

        do {
            let newChoiceItem = viewState.choices[current + 1]
            addScrollerCodes(into: &codes, scroller: scroller(
                appearance: appearance,
                viewState: viewState,
                choiceItem: newChoiceItem,
                isActive: true
            ))
            let textAttrs = textAttributes(
                appearance: appearance,
                viewState: viewState,
                choiceItem: newChoiceItem,
                isActive: true
            )
            codes.append(.setGraphicsRendition(setGraphicsModes(textAttributes: textAttrs)))
            codes.append(.literal(String(describing: newChoiceItem.choice)))
        }

        codes.append(.moveBottom(viewState: viewState))
    }
    outputCodes(codes)
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

@MainActor
func showStatus<T>(viewState: ViewState<T>) {
    let status = viewState.status
    withSavedCursorPosition {
        outputCodes([
            .moveBottom(viewState: viewState),
            .moveCursorUp(n: 1),
            .clearLine,
            .literal("  \(status.numberOfVisibleChoices)/\(status.numberOfChoices) (\(status.numberOfSelectedItems))"),
        ])
    }
}

enum Event<T: Selectable> {
    case key(TerminalKey?)
    case choice(T)
    case viewStateChanged
}

@MainActor
public func runSelector<T: Selectable, E: Error>(
    choices: some AsyncSequence<T, E> & Sendable,
    appearance: Appearance? = nil
) async throws -> [T] {
    let appearance = appearance ?? .default
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
    fillScreen(appearance: appearance, viewState: viewState)

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
            showStatus(viewState: viewState)
        case let .key(.character(character)):
            viewState.editFilter(.insert(character))
            showFilter(viewState: viewState)
            showStatus(viewState: viewState)
        case .key(.delete):
            viewState.editFilter(.delete)
            showFilter(viewState: viewState)
            showStatus(viewState: viewState)
        case .key(.deleteToEnd):
            viewState.editFilter(.deleteToEnd)
            showFilter(viewState: viewState)
            showStatus(viewState: viewState)
        case .key(.deleteToStart):
            viewState.editFilter(.deleteToStart)
            showFilter(viewState: viewState)
            showStatus(viewState: viewState)
        case .key(.down):
            withSavedCursorPosition {
                moveDown(appearance: appearance, viewState: viewState)
            }
            showFilter(viewState: viewState)
            showStatus(viewState: viewState)
        case .key(.moveToEnd):
            viewState.editFilter(.moveToEnd)
            showFilter(viewState: viewState)
        case .key(.moveToStart):
            viewState.editFilter(.moveToStart)
            showFilter(viewState: viewState)
        case .key(.tab):
            viewState.toggleCurrentSelection()
            withSavedCursorPosition {
                redrawChoices(appearance: appearance, viewState: viewState)
            }
            showStatus(viewState: viewState)
        case .key(.transpose):
            viewState.editFilter(.transpose)
            showFilter(viewState: viewState)
            showStatus(viewState: viewState)
        case .key(.up):
            withSavedCursorPosition {
                moveUp(appearance: appearance, viewState: viewState)
            }
            showFilter(viewState: viewState)
            showStatus(viewState: viewState)
        case .key(.terminate): break eventLoop
        case .key(nil): break
        case let .choice(choice):
            viewState.addChoice(choice)
            withSavedCursorPosition {
                redrawChoices(appearance: appearance, viewState: viewState)
            }
            showStatus(viewState: viewState)
        case .viewStateChanged:
            withSavedCursorPosition {
                redrawChoices(appearance: appearance, viewState: viewState)
            }
            showStatus(viewState: viewState)
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
