import Foundation
import Synchronization

final class DirectoryLister: Sendable {
    let root: URL

    private let cancelled: Mutex<Bool> = .init(false)

    init(root: URL) {
        self.root = root
    }

    func readContents(to callback: @escaping @Sendable (String) -> Void) {
        let basePath = self.root.standardizedFileURL.absoluteURL.path(percentEncoded: false)
        let basePathLength = basePath.count
        DispatchQueue(label: "fuzzytui.directoryLister").async {
            let enumerator = FileManager.default.enumerator(at: self.root, includingPropertiesForKeys: nil)!
            for case let fileURL as URL in enumerator {
                guard !(self.cancelled.withLock { $0 }) else { break }
                callback(
                    String(
                        fileURL.standardizedFileURL.absoluteURL.path(percentEncoded: false).dropFirst(basePathLength)
                    )
                )
            }
        }
    }

    nonisolated var contents: AsyncStream<String> {
        return AsyncStream<String> { continuation in
            continuation.onTermination = { _ in
                self.cancelled.withLock { $0 = true }
            }
            self.readContents { url in
                continuation.yield(url)
            }
        }
    }
}
