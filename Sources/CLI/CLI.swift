import ArgumentParser
import FuzzyTUI

@main
@MainActor
struct FuzzyCLI: AsyncParsableCommand {
    nonisolated static let configuration = CommandConfiguration(commandName: "sfzf")

    @Flag(name: .long, inversion: .prefixedNo)
    var installSignalHandlers: Bool = true

    @Flag(name: [.customShort("m"), .customLong("multi")])
    var multipleSelection: Bool = false

    mutating func run() async throws {
        let lines = (1...136).map { "line \($0)" }
        guard
            let selector = FuzzySelector(
                choices: AsyncArray(array: lines),
                installSignalHandlers: self.installSignalHandlers,
                multipleSelection: self.multipleSelection
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
