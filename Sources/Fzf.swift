import Foundation

func outputCode(_ code: ANSIControlCode) {
    try! FileHandle.standardOutput.write(contentsOf: Data(code.ansiCommand.message.utf8))
    // fdopen() on stdout is fast; also the returned file MUST NOT be fclose()d
    // This avoids concurrency complaints due to accessing global `stdout`.
    fflush(fdopen(STDOUT_FILENO, "w+"))
}

func fillScreen<T>(viewState: ViewState<T>) throws {
    outputCode(.clearScreen)
    let choices = viewState.choices.suffix(viewState.height - 1)
    let startLine = viewState.height - choices.count
    var lineNumber = 0
    for (index, choice) in zip(choices.indices, choices) {
        outputCode(.moveCursor(x: 0, y: startLine + index))
        print(index == viewState.current ? "> " : "  ", terminator: "")
        print(choice, lineNumber)
        lineNumber += 1
    }
}

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
        outputCode(.moveBottom(viewState: viewState))
        outputCode(.moveCursorUp(n: 1))
        outputCode(.scrollUp(1))

        viewState.moveDown()
        viewState.scrollDown()

        print("  ", viewState.choices[viewState.visibleLines.upperBound], separator: "")

        guard let newCurrentLine = viewState.line(forChoiceIndex: current + 1) else { fatalError() }

        outputCode(.moveCursor(x: 0, y: newCurrentLine))
        print("> ")

        outputCode(.moveBottom(viewState: viewState))
    }
}

@main
struct Fzf {
    static func main() throws -> Void {
        let terminalSize = TerminalSize.current()
        debug("----------------------------------------", reset: true)
        debug("Terminal height: \(terminalSize.height)")
        guard let tty = TTY(fileHandle: STDIN_FILENO) else {
            // TODO: error
            return
        }

        let lastLine = 20
        let viewState = ViewState(
            choices: (0 ... lastLine).map { "line\($0)" },
            height: terminalSize.height,
            maxWidth: terminalSize.width - 3,
            visibleLines: max(lastLine - terminalSize.height + 2, 0) ... (lastLine)
        )

        debug("Visible lines: \(viewState.visibleLines)")
        try fillScreen(viewState: viewState)
        while true {
            let key = try tty.withRawMode { () -> TerminalKey? in
                var buffer = [UInt8](repeating: 0, count: 3)
                let bytesRead = read(STDIN_FILENO, &buffer, 3)
                if bytesRead == 3 && buffer[0] == 0x1B && buffer[1] == 0x5B {
                    switch buffer[2] {
                    case 0x41: return .up
                    case 0x42: return .down
                    default: return nil
                    }
                }
                return nil
            }
            guard let key else { break }
            switch key {
            case .down: moveDown(viewState: viewState)
            case .up: moveUp(viewState: viewState)
            }
        }
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
