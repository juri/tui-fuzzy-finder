enum ANSIControlCode {
    case clearLine
    case clearScreen
    case disableAlternativeBuffer
    case enableAlternativeBuffer
    case insertLines(Int)
    case literal(String)
    case moveCursor(x: Int, y: Int)
    case moveCursorDown(n: Int)
    case moveCursorToColumn(n: Int)
    case moveCursorUp(n: Int)
    case restoreCursorPosition
    case restoreScreen
    case saveCursorPosition
    case saveScreen
    case setGraphicsRendition([SetGraphicsRendition])
    case scrollDown(Int)
    case scrollUp(Int)
    case setCursorHidden(Bool)

    var ansiCommand: ANSICommand {
        switch self {
        case .clearLine: return .init(rawValue: "[2K")
        case .clearScreen: return .init(rawValue: "[2J")
        case .disableAlternativeBuffer: return .init(rawValue: "[?1049l")
        case .enableAlternativeBuffer: return .init(rawValue: "[?1049h")
        case let .insertLines(n): return .init(rawValue: "[\(n)L")
        case let .literal(str): return .init(rawValue: str, escape: false)
        case let .moveCursor(x: x, y: y): return .init(rawValue: "[\(y + 1);\(x + 1)H")
        case let .moveCursorDown(n: n): return .init(rawValue: "[\(n)B")
        case let .moveCursorToColumn(n: n): return .init(rawValue: "[\(n)G")
        case let .moveCursorUp(n: n): return .init(rawValue: "[\(n)A")
        case .restoreCursorPosition: return .init(rawValue: "8")
        case .restoreScreen: return .init(rawValue: "[?47l")
        case .saveCursorPosition: return .init(rawValue: "7")
        case .saveScreen: return .init(rawValue: "[?47h")
        case let .scrollDown(n): return .init(rawValue: "[\(n)T")
        case let .scrollUp(n): return .init(rawValue: "[\(n)S")
        case let .setCursorHidden(hidden): return .init(rawValue: "[?25\(hidden ? "l" : "h")")
        case let .setGraphicsRendition(sgr):
            return .init(rawValue: "[\(sgr.map(\.parameters).joined(separator: ";"))m")
        }
    }

    @MainActor
    static func moveBottom<T>(viewState: ViewState<T>) -> Self {
        .moveCursor(x: 0, y: viewState.size.height - 1)
    }

    @MainActor
    static func moveToLastLine<T>(viewState: ViewState<T>) -> Self {
        .moveCursor(x: 0, y: viewState.size.height - 3)
    }
}

struct ANSICommand {
    var rawValue: String
    var escape: Bool = true

    var message: String {
        "\(self.escape ? "\u{001B}" : "")\(self.rawValue)"
    }
}

enum SetGraphicsRendition {
    case background256(Int)
    case backgroundBasic(BasicPalette)
    case backgroundBasicBright(BasicPalette)
    case backgroundRGB(red: Int, green: Int, blue: Int)
    case bold
    case italic
    case reset
    case text256(Int)
    case textBasic(BasicPalette)
    case textBasicBright(BasicPalette)
    case textRGB(red: Int, green: Int, blue: Int)
    case underline

    var parameters: String {
        switch self {
        case let .background256(index): return "48;5;\(index)"
        case let .backgroundBasic(p): return String(describing: 40 + p.rawValue)
        case let .backgroundBasicBright(p): return String(describing: 100 + p.rawValue)
        case let .backgroundRGB(red: r, green: g, blue: b): return "48;2;\(r);\(g);\(b)"
        case .bold: return "1"
        case .italic: return "3"
        case .underline: return "4"
        case let .text256(index): return "38;5;\(index)"
        case let .textBasic(p): return String(describing: 30 + p.rawValue)
        case let .textBasicBright(p): return String(describing: 90 + p.rawValue)
        case let .textRGB(red: r, green: g, blue: b): return "38;2;\(r);\(g);\(b)"
        case .reset: return "0"
        }
    }
}

/// `BasicPalette` contains the basic eight terminal colors.
public enum BasicPalette: Int, Sendable {
    case black = 0
    case red = 1
    case green = 2
    case yellow = 3
    case blue = 4
    case magenta = 5
    case cyan = 6
    case white = 7
}
