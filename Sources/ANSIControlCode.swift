//
//  ANSIControlCode.swift
//  swiftfzf
//
//  Created by Juri Pakaste on 3.11.2024.
//

enum ANSIControlCode {
    case clearLine
    case clearScreen
    case insertLines(Int)
    case literal(String)
    case moveCursor(x: Int, y: Int)
    case moveCursorDown(n: Int)
    case moveCursorToColumn(n: Int)
    case moveCursorUp(n: Int)
    case restoreCursorPosition
    case saveCursorPosition
    case scrollDown(Int)
    case scrollUp(Int)
    case setCursorHidden(Bool)

    var ansiCommand: ANSICommand {
        switch self {
        case .clearLine: return .init(rawValue: "[2K")
        case .clearScreen: return .init(rawValue: "[2J")
        case let .insertLines(n): return .init(rawValue: "[\(n)L")
        case let .literal(str): return .init(rawValue: str, escape: false)
        case let .moveCursor(x: x, y: y): return .init(rawValue: "[\(y + 1);\(x + 1)H")
        case let .moveCursorDown(n: n): return .init(rawValue: "[\(n)B")
        case let .moveCursorToColumn(n: n): return .init(rawValue: "[\(n)G")
        case let .moveCursorUp(n: n): return .init(rawValue: "[\(n)A")
        case .restoreCursorPosition: return .init(rawValue: "8")
        case .saveCursorPosition: return .init(rawValue: "7")
        case let .scrollDown(n): return .init(rawValue: "[\(n)T")
        case let .scrollUp(n): return .init(rawValue: "[\(n)S")
        case let .setCursorHidden(hidden): return .init(rawValue: "[?25\(hidden ? "l" : "h")")
        }
    }

    static func moveBottom<T>(viewState: ViewState<T>) -> Self {
        .moveCursor(x: 0, y: viewState.height - 1)
    }

    static func moveToLastLine<T>(viewState: ViewState<T>) -> Self {
        .moveCursor(x: 0, y: viewState.height - 3)
    }
}

struct ANSICommand {
    var rawValue: String
    var escape: Bool = true

    var message: String {
        "\(self.escape ? "\u{001B}" : "")\(self.rawValue)"
    }
}
