# Swift Terminal Fuzzy Finder

[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-2.1-4baaaa.svg)](code_of_conduct.md)

`tui-fuzzy-finder` is a [fzf] style text UI fuzzy finder library in Swift.

## Why

`fzf` is a fantastic tool, but if you're not into shell scripting, it can be be a drag. This library
aims to provide the core functionality of `fzf` in a Swift library, so you can write your tools
in Swift.

## What is included

`tui-fuzzy-finder` consists of a Swift library and an executable, `sfzf`, that uses it. The purpose
of `sfzf` is to make it easy to excercise the `tui-fuzzy-finder` features that are difficult to test
automatically. It does not try to compete with `fzf`.

## Goals

- Sufficient coverage of `fzf` features.
- Fast enough.

### Stretch goals

- Good platform coverage. PRs are welcome where it falls short.

## Non-goals

- Replacing `fzf` as a shell tool.
- Supporting the `fzf` features that only make sense in the shell scripting context.


[fzf]: https://github.com/junegunn/fzf
