//
//  TerminalSize.swift
//  swiftfzf
//
//  Created by Juri Pakaste on 3.11.2024.
//

import Foundation

struct TerminalSize {
    var height: Int
    var width: Int
}

extension TerminalSize {
    static func current() -> Self {
        var w = winsize()
        _ = ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &w)
        return TerminalSize(height: Int(w.ws_row), width: Int(w.ws_col))
    }
}
