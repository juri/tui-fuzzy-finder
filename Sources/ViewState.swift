//
//  ViewState.swift
//  swiftfzf
//
//  Created by Juri Pakaste on 3.11.2024.
//

final class ViewState<T: CustomStringConvertible> {
    let choices: [T]
    let height: Int

    var current: Int?
    var visibleLines: ClosedRange<Int>

    init(
        choices: [T],
        height: Int,
        maxWidth: Int,
        visibleLines: ClosedRange<Int>
    ) {
        self.choices = choices
        self.current = choices.isEmpty ? nil : choices.count - 1
        self.height = height
        self.visibleLines = visibleLines
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
        return max(0, (self.height - self.visibleLines.count)) + index - self.visibleLines.lowerBound - 1
    }
}

