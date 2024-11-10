public struct AsyncArray<Element>: AsyncSequence {
    public typealias Element = Element

    private let array: [Element]

    public init(array: [Element]) {
        self.array = array
    }

    public func makeAsyncIterator() -> AsyncIterator {
        return AsyncIterator(array: array)
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        public typealias Failure = Never

        private var array: [Element]
        private var index = 0

        init(array: [Element]) {
            self.array = array
        }

        public mutating func next() async throws -> Element? {
            guard !array.isEmpty else { return nil }
            return array.removeFirst()
        }
    }
}

extension AsyncArray: Sendable where Element: Sendable {}
