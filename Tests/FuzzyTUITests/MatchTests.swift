//
//  MatchTests.swift
//  tui-fuzzy-finder
//
//  Created by Juri Pakaste on 16.11.2024.
//

import Testing

@testable import FuzzyTUI

struct FuzzyTUITests {
    @Test(
        "Successful matches",
        arguments: [
            ("", ""),
            ("a", ""),
            ("aaa", ""),
            ("a", "a"),
            ("aa", "aa"),
            ("aaa", "a"),
            ("aaa", "aa"),
            ("abcd", "ab"),
            ("abcd", "ac"),
            ("abcd", "bc"),
            ("abcd", "cd"),
            ("abcd", "ad"),
            ("abcd", "bd"),
            ("abcd", "abc"),
            ("abcd", "bcd"),
            ("abcd", "abcd"),
            ("👯", "👯"),
        ]
    )
    func successfulMatches(_ string: String, _ filter: String) throws {
        #expect(isMatch(string, filter: filter, caseSensitive: true))
    }

    @Test(
        "Successful matches (case insensitive)",
        arguments: [
            ("", ""),
            ("a", ""),
            ("aaa", ""),
            ("a", "A"),
            ("aa", "AA"),
            ("aaa", "A"),
            ("aaa", "AA"),
            ("abcd", "AB"),
            ("abcd", "AC"),
            ("abcd", "BC"),
            ("abcd", "CD"),
            ("abcd", "AD"),
            ("abcd", "BD"),
            ("abcd", "ABC"),
            ("abcd", "BCD"),
            ("abcd", "ABCD"),
            ("👯", "👯"),
        ]
    )
    func successfulMatchesInsensitive(_ string: String, _ filter: String) throws {
        #expect(isMatch(string, filter: filter, caseSensitive: false))
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
        #expect(!isMatch(string, filter: filter, caseSensitive: true))
    }
}
