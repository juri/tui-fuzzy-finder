# Swift Terminal Fuzzy Finder

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fjuri%2Fswift-tui-fuzzy-finder%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/juri/swift-tui-fuzzy-finder)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fjuri%2Fswift-tui-fuzzy-finder%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/juri/swift-tui-fuzzy-finder)
[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-2.1-4baaaa.svg)](code_of_conduct.md)

`tui-fuzzy-finder` is a [fzf] style text UI fuzzy finder library in Swift. It lists the contents
of a asynchronous stream in the terminal, one item per line. The user can select one or multiple
items from the list and use fuzzy search to filter the list, and when they press return,
`tui-fuzzy-finder` returns the list of the selected items.

## Why

`fzf` is a fantastic tool, but if you're not into shell scripting, it can be be a drag. This library
aims to provide the core functionality of `fzf` in a Swift library, so you can write your tools
in Swift.

## What is included

`tui-fuzzy-finder` consists of a Swift library and an executable, `sfzf`, that uses it. The purpose
of `sfzf` is to make it easy to excercise the `tui-fuzzy-finder` features that are difficult to test
automatically. It does not try to compete with `fzf`.

## Command line usage

To build and install the executable run `swift build -c release`, then copy `.build/release/sfzf`
somewhere on your path.

Run `sfzf --help` to get information about command line arguments.

While the program is running:

- Move up and down with arrows
- Edit the filter line with normal line-editing commands
- Toggle selection with tab
- Press return to exit and write the selected lines to stdout

## Goals

- Sufficient coverage of `fzf` features.
- Fast enough.

### Stretch goals

- Good platform coverage. PRs are welcome where it falls short.

## Non-goals

- Replacing `fzf` as a shell tool.
- Supporting the `fzf` features that only make sense in the shell scripting context.


[fzf]: https://github.com/junegunn/fzf
