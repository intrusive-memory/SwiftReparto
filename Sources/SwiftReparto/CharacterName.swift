//
//  CharacterName.swift
//  SwiftReparto
//
//  Copyright (c) 2026 Intrusive Memory
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

import Foundation

/// Why a raw name has no canonical form (RQ-22).
///
/// ``CastMember/canonicalName(_:)`` never substitutes characters to make a
/// name acceptable: it either returns the canonical name or throws one of
/// these, carrying the input so a caller can report it.
public enum CharacterNameError: Error, LocalizedError, Equatable, Sendable {

  /// Nothing was left after stripping cue extensions, the `@` force-marker,
  /// and whitespace — for example `""`, `"   "`, or `"(V.O.)"`.
  ///
  /// - Parameter raw: The input, exactly as given.
  case empty(raw: String)

  /// The canonical name would contain `/` or `:`. Both are path separators
  /// somewhere, and a character name is used to build file names downstream.
  ///
  /// - Parameters:
  ///   - raw: The input, exactly as given.
  ///   - character: The offending character, `"/"` or `":"`.
  case forbiddenCharacter(raw: String, character: String)

  /// The canonical name would start with `.`, which makes a hidden file of
  /// anything named after it.
  ///
  /// - Parameter raw: The input, exactly as given.
  case leadingDot(raw: String)

  /// A human-readable description of the failure.
  public var errorDescription: String? {
    switch self {
    case .empty(let raw):
      return "The character name '\(raw)' is empty once cue extensions and whitespace are removed."
    case .forbiddenCharacter(let raw, let character):
      return
        "The character name '\(raw)' contains '\(character)', which a character name may not contain."
    case .leadingDot(let raw):
      return "The character name '\(raw)' starts with '.', which a character name may not do."
    }
  }
}

extension CastMember {

  /// The canonical form of a character name (RQ-22): the screenplay cue, in
  /// uppercase, with nothing else attached.
  ///
  /// A character is named exactly as its screenplay cue, uppercase,
  /// everywhere. This function defines that form for every consumer, because
  /// this is the leaf package all of them link. It applies, in order:
  ///
  /// 1. Strips a leading Fountain `@` force-marker, and strips trailing
  ///    parenthetical cue extensions repeatedly — `(V.O.)`, `(O.S.)`,
  ///    `(O.C.)`, `(CONT'D)`, and any other balanced `( … )` at the end.
  /// 2. Trims, and collapses internal whitespace runs to a single space.
  /// 3. Uppercases, locale-independently.
  /// 4. Normalizes to Unicode NFC.
  /// 5. Throws ``CharacterNameError`` when the result is empty, contains `/`
  ///    or `:`, or starts with `.`. **It never substitutes characters.**
  ///
  /// | Input | Output |
  /// |---|---|
  /// | `NARRATOR (V.O.)` | `NARRATOR` |
  /// | `@McCLANE` | `MCCLANE` |
  /// | `dr. o'neill` | `DR. O'NEILL` |
  /// | `GUARD #2` | `GUARD #2` |
  /// | `JOSÉ` | `JOSÉ` |
  ///
  /// The function is idempotent: a canonical name canonicalizes to itself.
  ///
  /// Decoding never calls this (RQ-INV-4). `character` stays exactly as the
  /// document wrote it; matching uses this form (see `merging(_:)`), and a
  /// caller that creates members from screenplay cues passes each name
  /// through here first.
  ///
  /// - Parameter raw: A name as it appears in a cue, a roster, or user input.
  /// - Returns: The canonical name.
  /// - Throws: ``CharacterNameError`` when no canonical form exists. The
  ///   throw is typed, so `catch` needs no fallback clause.
  public static func canonicalName(_ raw: String) throws(CharacterNameError) -> String {
    var name = Substring(raw)

    // 1. Cue decorations. Re-trim after every strip so `NARRATOR (V.O.) `
    //    and `X (V.O.) (CONT'D)` both reduce fully.
    name = trimmingWhitespace(name)
    if name.hasPrefix("@") {
      name = trimmingWhitespace(name.dropFirst())
    }
    while let stripped = droppingTrailingParenthetical(name) {
      name = trimmingWhitespace(stripped)
    }

    // 2. Whitespace shape.
    let collapsed =
      name
      .components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .joined(separator: " ")

    // 3–4. Case, then Unicode form. `uppercased()` with no locale is the
    //      Unicode default mapping, so `i` never becomes a dotted `İ`.
    let canonical = collapsed.uppercased().precomposedStringWithCanonicalMapping

    // 5. Refuse, never repair.
    if canonical.isEmpty {
      throw CharacterNameError.empty(raw: raw)
    }
    for forbidden in ["/", ":"] where canonical.contains(forbidden) {
      throw CharacterNameError.forbiddenCharacter(raw: raw, character: forbidden)
    }
    if canonical.hasPrefix(".") {
      throw CharacterNameError.leadingDot(raw: raw)
    }
    return canonical
  }

  /// Whether `character` is already in canonical form.
  ///
  /// `false` both when canonicalizing would change it and when it has no
  /// canonical form at all. `reparto validate` warns on either.
  public var hasCanonicalName: Bool {
    (try? Self.canonicalName(character)) == character
  }

  private static func trimmingWhitespace(_ text: Substring) -> Substring {
    var text = text
    while let first = text.first, first.isWhitespace { text.removeFirst() }
    while let last = text.last, last.isWhitespace { text.removeLast() }
    return text
  }

  /// `text` without its trailing balanced `( … )` group, or `nil` when it does
  /// not end in one.
  ///
  /// The group is found by walking back from the final `)` and counting
  /// depth, so a nested `(A (B))` is removed whole and an unbalanced
  /// `GUARD)` is left alone.
  private static func droppingTrailingParenthetical(_ text: Substring) -> Substring? {
    guard text.last == ")" else { return nil }
    var depth = 0
    var index = text.endIndex
    while index > text.startIndex {
      index = text.index(before: index)
      switch text[index] {
      case ")": depth += 1
      case "(":
        depth -= 1
        if depth == 0 { return text[text.startIndex..<index] }
      default: break
      }
    }
    return nil
  }
}
