//
//  ScoringMatchTests.swift
//  tui-fuzzy-finder
//
//  Created by Juri Pakaste on 17.12.2024.
//

import Testing

@testable import FuzzyTUI

struct ScoringMatchTests {
    @Test(
        "Successful matches",
        arguments: [
            ("", "", 0),
            ("foo", "foo", 0),
            ("foob", "foo", 0),
            ("afoo", "foo", 1),
            ("foao", "foo", 1),
            ("faoao", "foo", 2),
            ("afaoao", "foo", 3),
        ]
    )
    func successfulMatches(_ string: String, _ filter: String, _ score: Int) throws {
        #expect(scoreMatch(string, filter: filter, caseSensitive: true) == ScoredMatchResult.match(score: score))
    }

    @Test(
        "Failing matches",
        arguments: [
            ("", "a"),
            ("a", "aa"),
            ("aaa", "aaaa"),
            ("a", "b"),
            ("aa", "bb"),
            ("aaa", "ba"),
            ("aaa", "ab"),
            ("abcd", "ba"),
            ("abcd", "ca"),
            ("abcd", "cb"),
            ("abcd", "dc"),
            ("abcd", "da"),
            ("abcd", "db"),
            ("abcd", "e"),
            ("👯", "👯‍♀️"),
            ("a", "A"),
            ("aa", "AA"),
            ("aaa", "A"),
            ("aaa", "AA"),
        ]
    )
    func failingMatches(_ string: String, _ filter: String) throws {
        #expect(scoreMatch(string, filter: filter, caseSensitive: true) == .noMatch)
    }
}
