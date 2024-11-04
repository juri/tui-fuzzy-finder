//
//  ViewState.swift
//  swiftfzf
//
//  Created by Juri Pakaste on 3.11.2024.
//

@MainActor
final class ViewState<T: CustomStringConvertible> {
    let height: Int

    private(set) var choices: [T]
    var current: Int?
    private(set) var visibleLines: ClosedRange<Int>

    init(
        choices: [T],
        height: Int,
        maxWidth: Int
    ) {
        self.choices = choices
        self.current = choices.isEmpty ? nil : choices.count - 1
        self.height = height
        self.visibleLines = max(choices.count - height + 2, 0) ... max(choices.count - 1, 0)
    }

    func addChoice(_ choice: T) {
        self.choices.append(choice)
        self.visibleLines = max(choices.count - height + 2, 0) ... max(choices.count - 1, 0)
        if self.current == nil {
            self.current = 0
        }
    }

    func moveUp() {
        guard let current = self.current else { return }
        self.current = max(current - 1, 0)
    }

    func scrollUp() {
        let visibleLines = self.visibleLines
        guard visibleLines.lowerBound > 0 else { return }
        self.visibleLines = (visibleLines.lowerBound - 1) ... (visibleLines.upperBound - 1)
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
        self.visibleLines = (visibleLines.lowerBound + 1) ... (visibleLines.upperBound + 1)
    }

    var canScrollDown: Bool {
        self.visibleLines.upperBound < self.choices.count - 1
    }

    func line(forChoiceIndex index: Int) -> Int? {
        guard self.visibleLines.contains(index) else {
            return nil
        }
        return max(0, (self.height - self.visibleLines.count)) + index - self.visibleLines.lowerBound - 2
    }
}

