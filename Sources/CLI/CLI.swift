import FuzzyTUI

@main
@MainActor
struct Fzf {
    static func main() async throws {
        //        let choices = AsyncStream(unfolding: {
        //            try! await Task.sleep(for: .seconds(0.8))
        //            return "line \(Date())"
        //        })
        //        _ = try await runSelector(choices: choices)

        let lines = (1...136).map { "line \($0)" }
        _ = try await runSelector(choices: AsyncArray(array: lines))
    }
}
