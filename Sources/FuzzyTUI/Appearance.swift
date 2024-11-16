private let textColor: Appearance.Color = .palette256(15)
private let backgroundColor: Appearance.Color = .palette256(237)

public struct Appearance: Sendable {
    public var highlightedTextAttributes: Set<TextAttributes>
    public var highlightedSelectedTextAttributes: Set<TextAttributes>
    public var inactiveTextAttributes: Set<TextAttributes>
    public var selectedTextAttributes: Set<TextAttributes>

    public var highlightedScroller: Scroller
    public var highlightedSelectedScroller: Scroller
    public var inactiveScroller: Scroller
    public var selectedScroller: Scroller

    public static let `default` = Appearance(
        highlightedTextAttributes: [
            .background(backgroundColor),
            .foreground(textColor),
        ],
        highlightedSelectedTextAttributes: [
            .background(backgroundColor),
            .foreground(textColor),
        ],
        inactiveTextAttributes: [],
        selectedTextAttributes: [],

        highlightedScroller: .init(
            text: [
                TextPart(
                    text: "▌ ",
                    attributes: [
                        .background(backgroundColor),
                        .foreground(.palette256(200)),
                    ]
                )
            ]
        ),

        highlightedSelectedScroller: .init(
            text: [
                TextPart(
                    text: "▌",
                    attributes: [
                        .background(backgroundColor),
                        .foreground(.palette256(200)),
                    ]
                ),
                TextPart(
                    text: "┃",
                    attributes: [
                        .background(backgroundColor),
                        .foreground(.palette256(164)),
                    ]
                ),
            ]
        ),
        inactiveScroller: .init(
            text: [
                TextPart(
                    text: " ",
                    attributes: [
                        .background(backgroundColor)
                    ]
                ),
                TextPart(
                    text: " ",
                    attributes: []
                ),
            ]
        ),
        selectedScroller: .init(
            text: [
                TextPart(
                    text: " ",
                    attributes: [
                        .background(backgroundColor)
                    ]
                ),
                TextPart(
                    text: "┃",
                    attributes: [
                        .background(backgroundColor),
                        .foreground(.palette256(164)),
                    ]
                ),
            ]
        )
    )
}

public extension Appearance {
    enum Color: Hashable, Sendable {
        case basic(BasicPalette)
        case basicBright(BasicPalette)
        case palette256(Int)
        case rgb(red: Int, green: Int, blue: Int)
    }

    struct Scroller: Sendable {
        public var text: [TextPart]
    }

    struct TextPart: Sendable {
        public var text: String
        public var attributes: Set<TextAttributes>
    }

    enum TextAttributes: Hashable, Sendable {
        case background(Color)
        case bold
        case foreground(Color)
        case italic
        case underline
    }
}
