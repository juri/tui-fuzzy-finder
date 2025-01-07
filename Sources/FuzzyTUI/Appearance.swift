private let textColor: Appearance.Color = .palette256(231)
private let backgroundColor: Appearance.Color = .palette256(237)

/// `Appearance` contains the configuration parameters for the picker.
///
/// There is a default value available in the ``default`` field.
public struct Appearance: Sendable {
    /// Text attributes used for the text on the currently active line.
    public var highlightedTextAttributes: Set<TextAttributes>
    /// Text attributes used for the text on the currently active line if it has been selected.
    public var highlightedSelectedTextAttributes: Set<TextAttributes>
    /// Text used for unselected, inactive lines.
    public var inactiveTextAttributes: Set<TextAttributes>
    /// Text used for selected lines that are not currently active.
    public var selectedTextAttributes: Set<TextAttributes>

    /// Configuration for the scroller of the currently active line.
    public var highlightedScroller: Scroller
    /// Configuration for the scroller of the currently active line if it has been selected.
    public var highlightedSelectedScroller: Scroller
    /// Configuration for the scroller of unselected, inactive lines.
    public var inactiveScroller: Scroller
    /// Configuration for the scroller of selected lines that are not currently active.
    public var selectedScroller: Scroller

    /// Configuration for the appearance of the status line.
    public var status: Status

    /// Default appearance.
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
        ),
        status: Status(
            character: "─",
            attributes: [
                .foreground(backgroundColor)
            ]
        )
    )
}

public extension Appearance {
    /// Color values. Not all cases are supported by all terminals.
    enum Color: Hashable, Sendable {
        /// The eight basic terminal colors.
        case basic(BasicPalette)

        /// Bright variants of the eight basic terminal colors.
        case basicBright(BasicPalette)

        /// 256 color palette.
        ///
        /// - SeeAlso: The palette description [in Wikipedia](https://en.wikipedia.org/wiki/ANSI_escape_code#8-bit).
        case palette256(Int)

        /// 24 bit color defined by red, green and blue values in the 0…255 range.
        case rgb(red: Int, green: Int, blue: Int)
    }

    /// Configuration for leading edge scroller.
    struct Scroller: Sendable {
        /// List of attributed strings that are displayed as the scroller on a single line.
        public var text: [TextPart]
    }

    /// Configuration for the status line.
    struct Status: Sendable {
        /// The character to use for filling the status line after the counts.
        public var character: Character
        /// Attributes to use for the status line filler.
        public var attributes: Set<TextAttributes>
    }

    /// `TextPart` represents a run of characters with identical attributes.
    struct TextPart: Sendable {
        public var text: String
        public var attributes: Set<TextAttributes>
    }

    /// `TextAttributes` are attributes you can apply to text in terminal.
    enum TextAttributes: Hashable, Sendable {
        case background(Color)
        case bold
        case foreground(Color)
        case italic
        case underline
    }
}
