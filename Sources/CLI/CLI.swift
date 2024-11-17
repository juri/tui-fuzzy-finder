import ArgumentParser
import FuzzyTUI

@main
@MainActor
struct FuzzyCLI: AsyncParsableCommand {
    @Flag(name: [.customShort("m"), .customLong("multi")])
    var multipleSelection: Bool = false

    mutating func run() async throws {
        let lines = (1...136).map { "line \($0)" }
        let choices = try await runSelector(
            choices: AsyncArray(array: lines),
            multipleSelection: self.multipleSelection
        )
        for choice in choices {
            print(choice)
        }
    }
}
