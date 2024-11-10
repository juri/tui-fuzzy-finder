//
//  AsyncArray.swift
//  swiftfzf
//
//  Created by Juri Pakaste on 9.11.2024.
//

struct AsyncArray<Element>: AsyncSequence {
    typealias Element = Element

    let array: [Element]

    func makeAsyncIterator() -> AsyncIterator {
        return AsyncIterator(array: array)
    }

    struct AsyncIterator: AsyncIteratorProtocol {
        typealias Failure = Never

        private var array: [Element]
        private var index = 0

        init(array: [Element]) {
            self.array = array
        }

        mutating func next() async throws -> Element? {
            guard !array.isEmpty else { return nil }
            return array.removeFirst()
        }
    }
}

extension AsyncArray: Sendable where Element: Sendable {}
