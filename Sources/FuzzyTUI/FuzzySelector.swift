import AsyncAlgorithms
import Foundation
import UnixSignals

/// The type used for selectable items.
public typealias Selectable = CustomStringConvertible & Sendable & Equatable

@MainActor
final class FuzzySelectorView<T: Selectable> {
    private let appearance: Appearance
    private let viewState: ViewState<T>

    init(
        appearance: Appearance,
        viewState: ViewState<T>
    ) {
        self.appearance = appearance
        self.viewState = viewState
    }
}

extension FuzzySelectorView {
    func moveDown() {
        guard let current = self.viewState.current, current < self.viewState.choices.count - 1
        else { return }
        guard let currentLine = self.viewState.line(forChoiceIndex: current) else {
            fatalError()
        }

        var codes = [ANSIControlCode]()
        codes.append(.moveCursor(x: 0, y: currentLine))

        do {
            // clean up previous line
            let oldItem = self.viewState.choices[current]
            addScrollerCodes(
                into: &codes,
                scroller: self.scroller(
                    choiceItem: oldItem,
                    isActive: false
                ))
            codes.append(.setGraphicsRendition([.reset]))
            let textAttrs = self.textAttributes(
                choiceItem: oldItem,
                isActive: false
            )
            codes.append(.setGraphicsRendition(setGraphicsModes(textAttributes: textAttrs)))
            codes.append(.literal(String(describing: oldItem.choice)))
        }

        if currentLine < self.viewState.size.height - 4 || !self.viewState.canScrollDown {
            // we don't need to scroll or we can't scroll
            codes.append(.moveCursor(x: 0, y: currentLine + 1))
            self.viewState.moveDown()
            let newItem = self.viewState.choices[current + 1]
            addScrollerCodes(
                into: &codes,
                scroller: self.scroller(
                    choiceItem: newItem,
                    isActive: true
                ))

            codes.append(.setGraphicsRendition([.reset]))
            let textAttrs = self.textAttributes(
                choiceItem: newItem,
                isActive: true
            )
            codes.append(.setGraphicsRendition(setGraphicsModes(textAttributes: textAttrs)))
            codes.append(.literal(String(describing: newItem.choice)))

            outputCode(.moveBottom(viewState: self.viewState))
        } else {
            codes.append(.moveCursor(x: 0, y: 0))
            codes.append(.clearLine)
            codes.append(.moveToLastLine(viewState: self.viewState))
            codes.append(.scrollUp(1))

            self.viewState.moveDown()
            self.viewState.scrollDown()

            do {
                let newBottommostItem = self.viewState.choices[
                    self.viewState.visibleLines.upperBound]
                codes.append(.clearLine)
                addScrollerCodes(
                    into: &codes,
                    scroller: self.scroller(
                        choiceItem: newBottommostItem,
                        isActive: false
                    ))
                codes.append(.setGraphicsRendition([.reset]))
                let textAttrs = self.textAttributes(
                    choiceItem: newBottommostItem,
                    isActive: false
                )
                codes.append(.setGraphicsRendition(setGraphicsModes(textAttributes: textAttrs)))
                codes.append(.literal(String(describing: newBottommostItem.choice)))
            }

            guard let newCurrentLine = self.viewState.line(forChoiceIndex: current + 1) else {
                fatalError()
            }

            codes.append(.moveCursor(x: 0, y: newCurrentLine))

            do {
                let newChoiceItem = self.viewState.choices[current + 1]
                addScrollerCodes(
                    into: &codes,
                    scroller: self.scroller(
                        choiceItem: newChoiceItem,
                        isActive: true
                    ))
                let textAttrs = self.textAttributes(
                    choiceItem: newChoiceItem,
                    isActive: true
                )
                codes.append(.setGraphicsRendition(setGraphicsModes(textAttributes: textAttrs)))
                codes.append(.literal(String(describing: newChoiceItem.choice)))
            }

            codes.append(.moveBottom(viewState: self.viewState))
        }
        outputCodes(codes)
    }

    func moveUp() {
        guard let current = self.viewState.current, current > 0 else { return }
        guard let currentLine = self.viewState.line(forChoiceIndex: current) else {
            debug("moveUp didn't receive line for current \(current)")
            fatalError()
        }
        var codes = [ANSIControlCode]()
        codes.append(.moveCursor(x: 0, y: currentLine))

        do {
            // clean up previous line
            let oldItem = self.viewState.choices[current]
            addScrollerCodes(
                into: &codes,
                scroller: self.scroller(
                    choiceItem: oldItem,
                    isActive: false
                ))
            codes.append(.setGraphicsRendition([.reset]))
            let textAttrs = self.textAttributes(
                choiceItem: oldItem,
                isActive: false
            )
            codes.append(.setGraphicsRendition(setGraphicsModes(textAttributes: textAttrs)))
            codes.append(.literal(String(describing: oldItem.choice)))
        }

        if currentLine > 4 || !self.viewState.canScrollUp {
            // we don't need to scroll or we can't scroll
            codes.append(.moveCursor(x: 0, y: currentLine - 1))
            self.viewState.moveUp()
            let newItem = self.viewState.choices[current - 1]
            addScrollerCodes(
                into: &codes,
                scroller: self.scroller(
                    choiceItem: newItem,
                    isActive: true
                ))

            codes.append(.setGraphicsRendition([.reset]))
            let textAttrs = self.textAttributes(
                choiceItem: newItem,
                isActive: true
            )
            codes.append(.setGraphicsRendition(setGraphicsModes(textAttributes: textAttrs)))
            codes.append(.literal(String(describing: newItem.choice)))

            codes.append(.moveCursor(x: 0, y: self.viewState.size.height))
        } else {
            codes.append(.moveToLastLine(viewState: self.viewState))
            codes.append(.clearLine)
            codes.append(.moveCursor(x: 0, y: 0))
            codes.append(.insertLines(1))

            self.viewState.moveUp()
            self.viewState.scrollUp()

            do {
                let newTopmostItem = self.viewState.choices[self.viewState.visibleLines.lowerBound]

                codes.append(.clearLine)

                addScrollerCodes(
                    into: &codes,
                    scroller: self.scroller(
                        choiceItem: newTopmostItem,
                        isActive: false
                    ))

                codes.append(.setGraphicsRendition([.reset]))
                let textAttrs = self.textAttributes(
                    choiceItem: newTopmostItem,
                    isActive: false
                )
                codes.append(.setGraphicsRendition(setGraphicsModes(textAttributes: textAttrs)))
                codes.append(.literal(String(describing: newTopmostItem.choice)))
            }

            guard let newCurrentLine = self.viewState.line(forChoiceIndex: current - 1) else {
                fatalError()
            }
            codes.append(.moveCursor(x: 0, y: newCurrentLine))
            do {
                let newChoiceItem = self.viewState.choices[current - 1]
                addScrollerCodes(
                    into: &codes,
                    scroller: self.scroller(
                        choiceItem: newChoiceItem,
                        isActive: true
                    ))
                let textAttrs = self.textAttributes(
                    choiceItem: newChoiceItem,
                    isActive: true
                )
                codes.append(.setGraphicsRendition(setGraphicsModes(textAttributes: textAttrs)))
                codes.append(.literal(String(describing: newChoiceItem.choice)))
            }

            codes.append(.moveCursor(x: 0, y: self.viewState.size.height))
            codes.append(.clearLine)
        }
        outputCodes(codes)
    }

    func redrawChoices() {
        var codes = [ANSIControlCode]()
        codes.append(.moveCursor(x: 0, y: 0))
        codes.append(.clearLine)

        for _ in 0..<self.viewState.size.height - 2 {
            codes.append(.moveCursorDown(n: 1))
            codes.append(.clearLine)
        }

        guard !self.viewState.visibleLines.isEmpty, !self.viewState.choices.isEmpty else {
            outputCodes(codes)
            return
        }

        let choices = self.viewState.choices[self.viewState.visibleLines]
        guard
            let startLine = self.viewState.line(
                forChoiceIndex: self.viewState.visibleLines.lowerBound)
        else {
            fatalError()
        }
        for (lineNumber, (index, choiceItem)) in zip(0..., zip(choices.indices, choices)) {
            codes.append(.moveCursor(x: 0, y: startLine + lineNumber))

            let scroller = self.scroller(choiceItem: choiceItem, index: index)
            addScrollerCodes(into: &codes, scroller: scroller)
            codes.append(.setGraphicsRendition([.reset]))
            let textAttrs = self.textAttributes(
                choiceItem: choiceItem,
                index: index
            )
            codes.append(.setGraphicsRendition(setGraphicsModes(textAttributes: textAttrs)))
            codes.append(.literal(String(describing: choiceItem.choice)))
        }
        outputCodes(codes)
    }

    func showFilter() {
        outputCodes([
            .moveBottom(viewState: viewState),
            .clearLine,
            .literal(viewState.filter),
            .moveCursorToColumn(n: viewState.editPosition + 1),
        ])
    }

    func showStatus() {
        let status = viewState.status
        let lineStart = """
              \(status.numberOfVisibleChoices)/\(status.numberOfChoices) (\(status.numberOfSelectedItems))\u{0020}
            """
        let remainingSpace = self.viewState.size.width - lineStart.count
        let lineEnd = String(repeating: self.appearance.status.character, count: remainingSpace)

        withSavedCursorPosition {
            outputCodes([
                .moveBottom(viewState: viewState),
                .moveCursorUp(n: 1),
                .clearLine,
                .literal(lineStart),
                .setGraphicsRendition(setGraphicsModes(textAttributes: self.appearance.status.attributes)),
                .literal(lineEnd),
                .setGraphicsRendition([.reset]),
            ])
        }
    }
}

private extension FuzzySelectorView {
    func scroller(
        choiceItem: FilteredChoiceItem<T>,
        index: Int
    ) -> Appearance.Scroller {
        self.scroller(
            choiceItem: choiceItem,
            isActive: index == viewState.current
        )
    }

    func scroller(
        choiceItem: FilteredChoiceItem<T>,
        isActive: Bool
    ) -> Appearance.Scroller {
        switch (isActive, self.viewState.isSelected(choiceItem)) {
        case (false, false): return self.appearance.inactiveScroller
        case (false, true): return self.appearance.selectedScroller
        case (true, false): return self.appearance.highlightedScroller
        case (true, true): return self.appearance.highlightedSelectedScroller
        }
    }

    func textAttributes(
        choiceItem: FilteredChoiceItem<T>,
        index: Int
    ) -> Set<Appearance.TextAttributes> {
        textAttributes(
            choiceItem: choiceItem,
            isActive: index == viewState.current
        )
    }

    func textAttributes(
        choiceItem: FilteredChoiceItem<T>,
        isActive: Bool
    ) -> Set<Appearance.TextAttributes> {
        switch (isActive, self.viewState.isSelected(choiceItem)) {
        case (false, false): return self.appearance.inactiveTextAttributes
        case (false, true): return self.appearance.selectedTextAttributes
        case (true, false): return self.appearance.highlightedTextAttributes
        case (true, true): return self.appearance.highlightedTextAttributes
        }
    }
}

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

func addScrollerCodes(into codes: inout [ANSIControlCode], scroller: Appearance.Scroller) {
    for textItem in scroller.text {
        let sgr = setGraphicsModes(textAttributes: textItem.attributes)
        codes.append(.setGraphicsRendition([.reset]))
        codes.append(.setGraphicsRendition(sgr))
        codes.append(.literal(textItem.text))
    }
}

enum Event<T: Selectable> {
    case key(TerminalKey?)
    case choice([T])
    case continueSignal
    case viewStateChanged
}

/// `FuzzySelector` is the entry point to use for displaying a selector.
@MainActor
public final class FuzzySelector<T: Selectable, E: Error, Seq> where Seq: AsyncSequence<T, E> & Sendable {
    private let choices: Seq
    private let installSignalHandlers: Bool
    private let multipleSelection: Bool
    private let tty: TTY
    private let view: FuzzySelectorView<T>
    private let viewState: ViewState<T>

    /// Initialize a `FuzzySelector`.
    public init?(
        choices: Seq,
        appearance: Appearance? = nil,
        installSignalHandlers: Bool = true,
        matchMode: MatchMode? = nil,
        multipleSelection: Bool = true
    ) {
        let appearance = appearance ?? .default
        let terminalSize = TerminalSize.current()
        guard let tty = TTY(fileHandle: STDIN_FILENO) else {
            // TODO: error
            return nil
        }

        let viewState = ViewState(
            choices: [T](),
            matchMode: matchMode ?? .caseSensitiveIfFilterContainsUppercase,
            maxWidth: terminalSize.width - 3,
            size: terminalSize
        )

        self.choices = choices
        self.installSignalHandlers = installSignalHandlers
        self.multipleSelection = multipleSelection
        self.tty = tty
        self.view = FuzzySelectorView(appearance: appearance, viewState: viewState)
        self.viewState = viewState
    }

    /// Run the selector.
    ///
    /// The `run` method consumes the `choices` sequence given in init and asynchronously returns the selected items.
    public func run() async throws -> [T] {
        let keyReader = KeyReader(tty: tty)
        outputCodes([
            .setCursorHidden(true),
            .saveCursorPosition,
            .saveScreen,
            .enableAlternativeBuffer,
        ])

        try self.tty.setRaw()

        let keyEvents = keyReader.keys
            .map { keyResult throws -> Event<T> in
                switch keyResult {
                case let .success(key): return Event.key(key)
                case let .failure(error): throw error
                }
            }
        let viewStateUpdateEvents = self.viewState.changed
            .map { Event<T>.viewStateChanged }

        let choiceEvents =
            choices
            .chunked(by: .repeating(every: .milliseconds(100)))
            .map { choices -> Event<T> in .choice(choices) }

        let signals: [UnixSignal] = if self.installSignalHandlers { [.sigcont] } else { [] }
        let signalsSequence = await UnixSignalsSequence(trapping: signals)
            .map { _ in Event<T>.continueSignal }

        var selection = [T]()
        let events = merge(keyEvents, choiceEvents, merge(viewStateUpdateEvents, signalsSequence))

        eventLoop: for try await event in events {
            debug("got event: \(event)")
            switch event {
            case .continueSignal:
                try self.continueAfterSuspension()
            case .key(.backspace):
                self.viewState.editFilter(.backspace)
                self.view.showFilter()
                self.view.showStatus()
            case let .key(.character(character)):
                self.viewState.editFilter(.insert(character))
                self.view.showFilter()
                self.view.showStatus()
            case .key(.delete):
                self.viewState.editFilter(.delete)
                self.view.showFilter()
                self.view.showStatus()
            case .key(.deleteToEnd):
                self.viewState.editFilter(.deleteToEnd)
                self.view.showFilter()
                self.view.showStatus()
            case .key(.deleteToStart):
                self.viewState.editFilter(.deleteToStart)
                self.view.showFilter()
                self.view.showStatus()
            case .key(.down):
                withSavedCursorPosition {
                    self.view.moveDown()
                }
                self.view.showFilter()
                self.view.showStatus()
            case .key(.moveToEnd):
                self.viewState.editFilter(.moveToEnd)
                self.view.showFilter()
            case .key(.moveToStart):
                self.viewState.editFilter(.moveToStart)
                self.view.showFilter()
            case .key(.return):
                if self.multipleSelection {
                    selection = self.viewState.unfilteredSelection.map { self.viewState.unfilteredChoices[$0] }
                } else if let current = self.viewState.current {
                    selection = [self.viewState.unfilteredChoices[current]]
                }
                break eventLoop
            case .key(.suspend):
                try self.tty.unsetRaw()
                outputCodes([
                    .disableAlternativeBuffer,
                    .restoreScreen,
                ])
                let pid = ProcessInfo.processInfo.processIdentifier
                let pgid = getpgid(pid)
                let target = pgid * -1
                kill(target, SIGTSTP)
            case .key(.tab):
                if self.multipleSelection {
                    self.viewState.toggleCurrentSelection()
                    withSavedCursorPosition {
                        self.view.redrawChoices()
                    }
                    self.view.showStatus()
                }
            case .key(.terminate): break eventLoop
            case .key(.transpose):
                self.viewState.editFilter(.transpose)
                self.view.showFilter()
                self.view.showStatus()
            case .key(.up):
                withSavedCursorPosition {
                    self.view.moveUp()
                }
                self.view.showFilter()
                self.view.showStatus()
            case .key(nil): break
            case let .choice(choices):
                self.viewState.addChoices(choices)
                withSavedCursorPosition {
                    self.view.redrawChoices()
                }
                self.view.showStatus()
            case .viewStateChanged:
                withSavedCursorPosition {
                    self.view.redrawChoices()
                }
                self.view.showStatus()
            case .key(.some(.left)):
                self.viewState.editFilter(.left)
                self.view.showFilter()
            case .key(.some(.right)):
                self.viewState.editFilter(.right)
                self.view.showFilter()
            }
        }
        try self.tty.unsetRaw()
        outputCodes([
            .disableAlternativeBuffer,
            .restoreScreen,
            .restoreCursorPosition,
        ])
        return selection
    }

    /// Continue running after suspension.
    ///
    /// If you've specified `installSignalHandlers` to
    /// ``init(choices:appearance:installSignalHandlers:matchMode:multipleSelection:)`` as true,
    /// you do not need to call this method. But if you want to handle SIGCONT in the program running
    /// the selector, call this method to resume the selector.
    public func continueAfterSuspension() throws {
        try self.tty.setRaw()
        self.view.redrawChoices()
        self.view.showFilter()
        self.view.showStatus()
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
