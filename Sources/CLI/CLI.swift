import ArgumentParser
import Foundation
import FuzzyTUI

@main
@MainActor
struct FuzzyCLI: AsyncParsableCommand {
    nonisolated static let configuration = CommandConfiguration(commandName: "sfzf")

    @Flag(name: .long, inversion: .prefixedNo)
    var installSignalHandlers: Bool = true

    @Flag(name: [.customShort("m"), .customLong("multi")])
    var multipleSelection: Bool = false

    @Flag
    var reverse: Bool = false

    @Option(name: [.customShort("C"), .customLong("case")])
    var caseSensitivity: CaseSensitivity = .smart

    mutating func run() async throws {
        let lines = DirectoryLister(root: URL(string: ".")!).contents
        guard
            let selector = FuzzySelector(
                choices: lines,
                installSignalHandlers: self.installSignalHandlers,
                matchCaseSensitivity: self.caseSensitivity.matchCaseSensitivity,
                multipleSelection: self.multipleSelection,
                reverse: self.reverse
            )
        else {
            return
        }
        let choices = try await selector.run()

        for choice in choices {
            print(choice)
        }
    }
}

enum CaseSensitivity: Decodable {
    case sensitive
    case insensitive
    case smart
}

extension CaseSensitivity: ExpressibleByArgument {
    init?(argument: String) {
        switch argument.lowercased() {
        case "sensitive":
            self = .sensitive
        case "insensitive":
            self = .insensitive
        case "smart":
            self = .smart
        default:
            return nil
        }
    }
}

extension CaseSensitivity {
    var matchCaseSensitivity: MatchCaseSensitivity {
        switch self {
        case .sensitive: return .caseSensitive
        case .insensitive: return .caseInsensitive
        case .smart: return .caseSensitiveIfFilterContainsUppercase
        }
    }
}
