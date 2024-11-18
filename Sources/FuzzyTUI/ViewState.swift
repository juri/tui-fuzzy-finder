@MainActor
final class ViewState<T: Selectable> {
    let size: TerminalSize

    var current: Int?

    private let choiceFilter: ChoiceFilter<T>
    private let outputStream: AsyncStream<Void>

    private(set) var choices: [FilteredChoiceItem<T>]
    private(set) var editPosition: Int = 0
    private(set) var unfilteredChoices: [T]
    private(set) var visibleLines: ClosedRange<Int>
    private(set) var unfilteredSelection: Set<Int> = []

    private var _filter: String = ""

    init(
        choices: [T],
        matchCaseSensitivity: MatchCaseSensitivity,
        maxWidth: Int,
        size: TerminalSize
    ) {
        self.choices = choices.enumerated().map(FilteredChoiceItem.init(index:choice:))
        self.unfilteredChoices = choices
        self.choiceFilter = ChoiceFilter(matchCaseSensitivity: matchCaseSensitivity)
        self.current = choices.isEmpty ? nil : choices.count - 1
        self.size = size
        self.visibleLines = max(choices.count - size.height + 2, 0)...max(choices.count - 1, 0)

        let (outputStream, outputContinuation) = AsyncStream<Void>.makeStream(
            bufferingPolicy: .bufferingNewest(1))
        self.outputStream = outputStream

        Task {
            for await filteredChoices in self.choiceFilter.output {
                let visibleLines =
                    max(filteredChoices.count - size.height + 2, 0)...max(filteredChoices.count - 1, 0)
                let visibleLinesChanged = visibleLines != self.visibleLines
                self.visibleLines = visibleLines

                let oldCurrent = self.current
                if filteredChoices.count == 0 {
                    self.current = nil
                } else if var current = self.current {
                    current += filteredChoices.count - self.choices.count
                    if !visibleLines.contains(current) {
                        current = visibleLines.lowerBound
                    }
                    self.current = current
                } else if self.current == nil {
                    self.current = filteredChoices.count - 1
                }
                let currentChanged = self.current != oldCurrent

                let choicesChanged = self.choices != filteredChoices
                self.choices = filteredChoices

                guard choicesChanged || currentChanged || visibleLinesChanged else { continue }
                outputContinuation.yield()
            }
        }
    }

    func addChoices(_ choices: [T]) {
        self.unfilteredChoices.append(contentsOf: choices)
        self.choiceFilter.addJob(.init(choices: self.unfilteredChoices, filter: self.filter))
    }

    func editFilter(_ action: EditAction) {
        switch action {
        case .backspace:
            var filter = self._filter
            if self.editPosition > 0 {
                filter.remove(at: filter.index(filter.startIndex, offsetBy: self.editPosition - 1))
                self.filter = filter
                self.editPosition -= 1
            }
        case .delete:
            var filter = self._filter
            let index = filter.index(filter.startIndex, offsetBy: self.editPosition)
            if index < filter.endIndex {
                filter.remove(at: index)
                self.filter = filter
            }
        case .deleteToEnd:
            var filter = self._filter
            let index = filter.index(filter.startIndex, offsetBy: self.editPosition)
            filter.removeSubrange(index...)
            self.filter = filter
        case .deleteToStart:
            var filter = self._filter
            let index = filter.index(filter.startIndex, offsetBy: self.editPosition)
            filter.removeSubrange(filter.startIndex..<index)
            self.filter = filter
            self.editPosition = 0
        case let .insert(character):
            var filter = self._filter
            filter.insert(
                character,
                at: filter.index(filter.startIndex, offsetBy: self.editPosition)
            )
            self.filter = filter
            self.editPosition += 1
        case .left:
            self.editPosition = max(self.editPosition - 1, 0)
        case .moveToEnd:
            self.editPosition = self.filter.count
        case .moveToStart:
            self.editPosition = 0
        case .right:
            self.editPosition = min(self.editPosition + 1, self._filter.count)
        case .transpose:
            var filter = self.filter
            let index = filter.index(filter.startIndex, offsetBy: self.editPosition)
            guard index < filter.endIndex && index > filter.startIndex else { return }
            let previousIndex = filter.index(before: index)
            let nextIndex = filter.index(after: index)
            let (currentCharacter, previousCharacter) = (filter[index], filter[previousIndex])
            filter.replaceSubrange(previousIndex..<index, with: String(currentCharacter))
            filter.replaceSubrange(index..<nextIndex, with: String(previousCharacter))
            self.filter = filter
        }
    }

    private(set) var filter: String {
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
        return max(0, (self.size.height - self.visibleLines.count)) + index
            - self.visibleLines.lowerBound - 2
    }

    @discardableResult
    func toggleCurrentSelection() -> Bool {
        guard let current = self.current else { return false }
        return self.toggleSelection(current)
    }

    @discardableResult
    func toggleSelection(_ index: Int) -> Bool {
        let unfilteredIndex = self.choices[index].index
        let isSelected = !self.unfilteredSelection.contains(unfilteredIndex)
        if isSelected {
            self.unfilteredSelection.insert(unfilteredIndex)
        } else {
            self.unfilteredSelection.remove(unfilteredIndex)
        }

        return isSelected
    }

    func isSelected(_ choiceItem: FilteredChoiceItem<T>) -> Bool {
        let unfilteredIndex = choiceItem.index
        return self.unfilteredSelection.contains(unfilteredIndex)
    }

    var status: StatusValues {
        StatusValues(
            numberOfChoices: self.unfilteredChoices.count,
            numberOfVisibleChoices: self.choices.count,
            numberOfSelectedItems: self.unfilteredSelection.count
        )
    }
}

extension ViewState {
    enum EditAction {
        case backspace
        case delete
        case deleteToEnd
        case deleteToStart
        case insert(Character)
        case left
        case moveToEnd
        case moveToStart
        case right
        case transpose
    }

    struct StatusValues {
        var numberOfChoices: Int
        var numberOfVisibleChoices: Int
        var numberOfSelectedItems: Int
    }
}

private actor ChoiceFilter<T: Selectable> {
    struct Job {
        var choices: [T]
        var filter: String
    }

    private typealias InputStream = AsyncStream<Job>
    private typealias OutputStream = AsyncStream<[FilteredChoiceItem<T>]>

    private let inputContinuation: InputStream.Continuation
    private let matchCaseSensitivity: MatchCaseSensitivity
    private let outputContinuation: OutputStream.Continuation

    private let outputStream: OutputStream

    init(
        matchCaseSensitivity: MatchCaseSensitivity
    ) {
        let (inputStream, inputContinuation) = InputStream.makeStream(
            bufferingPolicy: .bufferingNewest(1))
        let (outputStream, outputContinuation) = OutputStream.makeStream(
            bufferingPolicy: .bufferingNewest(1))

        self.inputContinuation = inputContinuation
        self.matchCaseSensitivity = matchCaseSensitivity
        self.outputContinuation = outputContinuation

        self.outputStream = outputStream

        Task {
            for await job in inputStream {
                let filtered = await self.run(job)
                outputContinuation.yield(filtered)
            }
        }
    }

    nonisolated var output: some AsyncSequence<[FilteredChoiceItem<T>], Never> & Sendable {
        self.outputStream
    }

    nonisolated func addJob(
        @_inheritActorContext _ job: Job
    ) {
        self.inputContinuation.yield(job)
    }
}

extension ChoiceFilter {
    private func run(_ job: Job) async -> [FilteredChoiceItem<T>] {
        guard !job.filter.isEmpty else {
            return job.choices.enumerated().map(FilteredChoiceItem.init(index:choice:))
        }

        let caseSensitive: Bool
        switch self.matchCaseSensitivity {
        case .caseSensitive: caseSensitive = true
        case .caseInsensitive: caseSensitive = false
        case .caseSensitiveIfFilterContainsUppercase: caseSensitive = job.filter.contains(where: { $0.isUppercase })
        }

        let filtered = job.choices.enumerated().filter {
            isMatch($1.description, filter: job.filter, caseSensitive: caseSensitive)
        }.map(FilteredChoiceItem.init(index:choice:))
        return filtered
    }
}

func isMatch(_ string: String, filter: String, caseSensitive: Bool) -> Bool {
    var characters = Array(caseSensitive ? string : string.lowercased())
    let filterCharacters = Array(caseSensitive ? filter : filter.lowercased())
    for filterCharacter in filterCharacters {
        guard let index = characters.firstIndex(of: filterCharacter) else {
            return false
        }
        characters.removeFirst(index + 1)
    }
    return true
}

/// `MatchCaseSensitivity` describes how case is handled while matching.
public enum MatchCaseSensitivity: Sendable {
    /// Require matching case.
    case caseSensitive

    /// Don't require matching case.
    case caseInsensitive

    /// Require matching case if the match string contains uppercase letters.
    case caseSensitiveIfFilterContainsUppercase
}

struct FilteredChoiceItem<T: Selectable>: Equatable {
    var index: Int
    var choice: T
}
