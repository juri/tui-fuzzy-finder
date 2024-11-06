//
//  ViewState.swift
//  swiftfzf
//
//  Created by Juri Pakaste on 3.11.2024.
//

@MainActor
final class ViewState<T: CustomStringConvertible & Sendable> {
    let height: Int

    var current: Int?

    private let choiceFilter: ChoiceFilter<T>
    private let outputStream: AsyncStream<Void>

    private(set) var choices: [T]
    private(set) var unfilteredChoices: [T]
    private(set) var visibleLines: ClosedRange<Int>
    private var _filter: String = ""

    init(
        choices: [T],
        height: Int,
        maxWidth: Int
    ) {
        self.choices = choices
        self.unfilteredChoices = choices
        self.choiceFilter = ChoiceFilter()
        self.current = choices.isEmpty ? nil : choices.count - 1
        self.height = height
        self.visibleLines = max(choices.count - height + 2, 0)...max(choices.count - 1, 0)

        let (outputStream, outputContinuation) = AsyncStream<Void>.makeStream(
            bufferingPolicy: .bufferingNewest(1))
        self.outputStream = outputStream

        Task {
            for await filteredChoices in self.choiceFilter.output {
                self.choices = filteredChoices

                self.visibleLines =
                    max(filteredChoices.count - height + 2, 0)...max(filteredChoices.count - 1, 0)
                if filteredChoices.count == 0 {
                    self.current = nil
                } else if self.current == nil {
                    self.current = 0
                }

                outputContinuation.yield()
            }
        }
    }

    func addChoice(_ choice: T) {
        self.unfilteredChoices.append(choice)
        self.choiceFilter.addJob(.init(choices: self.unfilteredChoices, filter: self.filter))
    }

    var filter: String {
        get { self._filter }
        set {
            self._filter = newValue
            self.choiceFilter.addJob(.init(choices: self.unfilteredChoices, filter: newValue))
        }
    }

    var changed: some AsyncSequence<Void, Never> & Sendable {
        self.outputStream
    }

    func moveUp() {
        guard let current = self.current else { return }
        self.current = max(current - 1, 0)
    }

    func scrollUp() {
        let visibleLines = self.visibleLines
        guard visibleLines.lowerBound > 0 else { return }
        self.visibleLines = (visibleLines.lowerBound - 1)...(visibleLines.upperBound - 1)
    }

    var canScrollUp: Bool {
        self.visibleLines.lowerBound > 0
    }

    func moveDown() {
        guard let current = self.current else { return }
        self.current = min(current + 1, self.choices.count - 1)
    }

    func scrollDown() {
        let visibleLines = self.visibleLines
        guard visibleLines.upperBound < self.choices.count - 1 else { return }
        self.visibleLines = (visibleLines.lowerBound + 1)...(visibleLines.upperBound + 1)
    }

    var canScrollDown: Bool {
        self.visibleLines.upperBound < self.choices.count - 1
    }

    func line(forChoiceIndex index: Int) -> Int? {
        guard self.visibleLines.contains(index) else {
            return nil
        }
        return max(0, (self.height - self.visibleLines.count)) + index
            - self.visibleLines.lowerBound - 2
    }
}

private actor ChoiceFilter<T: CustomStringConvertible & Sendable> {
    struct Job {
        var choices: [T]
        var filter: String
    }

    private typealias InputStream = AsyncStream<Job>
    private typealias OutputStream = AsyncStream<[T]>

    private let inputContinuation: InputStream.Continuation
    private let outputContinuation: OutputStream.Continuation

    private let outputStream: OutputStream

    init() {
        let (inputStream, inputContinuation) = InputStream.makeStream(
            bufferingPolicy: .bufferingNewest(1))
        let (outputStream, outputContinuation) = OutputStream.makeStream(
            bufferingPolicy: .bufferingNewest(1))

        self.inputContinuation = inputContinuation
        self.outputContinuation = outputContinuation

        self.outputStream = outputStream

        Task {
            for await job in inputStream {
                let filtered = await self.run(job)
                outputContinuation.yield(filtered)
            }
        }
    }

    nonisolated var output: some AsyncSequence<[T], Never> & Sendable {
        self.outputStream
    }

    nonisolated func addJob(
        @_inheritActorContext _ job: Job
    ) {
        self.inputContinuation.yield(job)
    }
}

extension ChoiceFilter {
    private func run(_ job: Job) async -> [T] {
        guard !job.filter.isEmpty else { return job.choices }
        let filtered = job.choices.filter { $0.description.contains(job.filter) }
        return filtered
    }
}
