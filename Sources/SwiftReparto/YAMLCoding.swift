//
//  YAMLCoding.swift
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
import Yams

// THIS IS THE ONLY FILE IN THE PACKAGE PERMITTED TO `import Yams` (D-1).
//
// Every other file names Foundation types only and reaches YAML through the
// two functions below. That is not stylistic tidiness: it keeps the YAML
// implementation swappable behind a two-function seam, and it gives the
// leaf-invariant guard a single line to check instead of a whole tree to
// audit. If you are about to add `import Yams` to `CastMarkdownParser.swift`
// or to a `PROJECT.md` importer, add a function here instead.

// MARK: - Encoding

/// Serializes a `Codable` value to a YAML document.
///
/// This is the single emission path for everything this library writes. The
/// encoder is configured here, in one place, and never inherits a Yams default
/// — see the configuration block for why each field is set the way it is.
///
/// - Parameter value: The value to serialize. In practice this is a
///   ``CastDocument``'s front matter.
/// - Returns: The emitted YAML, with LF line endings and no document markers.
/// - Throws: `EncodingError` if the value cannot be represented.
func encodeYAML<Value: Encodable>(_ value: Value) throws -> String {
  // Constructed here, in the function body, and never stored (D-1 / RQ-15).
  //
  // `YAMLEncoder` is a non-`Sendable` `public class` with a mutable `options`
  // property. Holding one as a stored property would make every type that
  // holds it non-`Sendable`, and `CastMarkdownParser` is required to be
  // `Sendable`. A fresh instance per call also means no call can observe
  // options another call left behind.
  let encoder = YAMLEncoder()

  // EVERY FIELD BELOW IS SET EXPLICITLY. None of these values may be left to
  // the Yams default, and the two that differ from it are the load-bearing
  // ones.

  // REQUIRED, and the default is wrong for us. Yams defaults `width` to 0,
  // which libyaml reads as "best width" (80 columns) and which folds a long
  // plain scalar across several lines. Real cast data carries ~400-character
  // `bio:` prose in an undeclared key; folded, it survives a round trip as a
  // *value* but not as *bytes*, and byte identity is the gate. -1 means
  // unlimited: one logical line stays one physical line.
  encoder.options.width = -1

  // Two spaces per level. Set explicitly because the Yams default is 0, which
  // means "let libyaml pick" — a defensible default and an indefensible input
  // to a SHA-256 comparison.
  encoder.options.indent = 2

  // LF, never CRLF. Body bytes are preserved verbatim elsewhere; the front
  // matter this encoder emits is generated, and it is generated the same way
  // on every platform.
  encoder.options.lineBreak = .ln

  // KEY ORDER IS GUARANTEED AT THE `encode(to:)` LAYER, NOT HERE.
  //
  // Emitted key order must be identical across runs, and `[String: AnyCodable]`
  // iteration order is not stable across processes. The fix lives in the model
  // types: `CastMember.encode(to:)` writes its declared `CodingKeys` in
  // declaration order and then appends `extraKeys` in `keys.sorted()` order,
  // and `CastDocument.encode(to:)` writes `type`, `schemaVersion`, `cast` in
  // that fixed order. Yams preserves the insertion order of a mapping, so
  // leaving key sorting off is what lets those guarantees reach the file.
  //
  // Lexicographic sorting here is NOT an available alternative, and the reason
  // is not aesthetic: it would rewrite the front matter as `cast`,
  // `schemaVersion`, `type`, contradicting the fixed `type` → `schemaVersion`
  // → `cast` order the document format requires. Declaration order satisfies
  // both requirements at once; sorting satisfies neither. Do not enable this.
  encoder.options.sortKeys = false

  // Emit non-ASCII as UTF-8 rather than as `\uXXXX` escapes. `CAST.md` is a
  // hand-edited file: an actor named `José` and an em dash in a `bio:` must
  // read as themselves. Round-trip fidelity is identical either way, so this
  // is chosen for the human and pinned so it cannot drift.
  encoder.options.allowUnicode = true

  // No `---` / `...` markers from the emitter. The front-matter delimiters are
  // written by the markdown layer, which owns where they go; a second set from
  // in here would be a duplicate.
  encoder.options.explicitStart = false
  encoder.options.explicitEnd = false

  // No `%YAML` directive, and no canonical (fully tagged, fully quoted) form.
  // Both are legal YAML and neither is what a human-edited front-matter block
  // looks like.
  encoder.options.version = nil
  encoder.options.canonical = false

  // Let libyaml choose the presentation for a scalar containing newlines.
  // Pinned explicitly so a future Yams default change is a compile-time-visible
  // decision here rather than a silent reformat of everyone's files.
  encoder.options.newLineScalarStyle = .any

  return try encoder.encode(value)
}

// MARK: - Decoding

// MARK: - The dialect this library reads
//
// THIS LIBRARY READS YAML 1.2 CORE-SCHEMA SEMANTICS THROUGH A YAML 1.1 PARSER,
// AND WHERE EVEN YAML 1.2 CORE WOULD CHANGE AN AUTHOR'S SPELLING IT DECLINES TO
// PARSE A NUMBER AT ALL.
//
// libyaml — and therefore Yams — implements YAML 1.1. Two families of its
// implicit typing rules reach this library, and the pass below narrows both.
//
// ## Family 1: booleans (Sortie 8b)
//
// YAML 1.1 says the plain scalars `yes`, `no`, `on`, `off`, `y`, and `n` are
// booleans. YAML 1.2's core schema narrowed that set to exactly six spellings:
// `true`, `True`, `TRUE`, `false`, `False`, `FALSE`. Everything else is a
// string.
//
// ## Family 2: numbers (Sortie 9a)
//
// YAML 1.1 additionally resolves sexagesimals (`12:34` -> 754, `1:00:00` ->
// 3600), bare-leading-zero octal (`0755` -> 493), and `_` digit separators
// (`1_000` -> 1000). Yams goes further still and accepts `0b1011`, `0o17`, and
// `0x1f`. `0755` is the worst of these: it is a silent *value* mutation, since
// YAML 1.2 core reads the same characters as decimal 755.
//
// ## Why the narrower dialect is the one we want (RQ-4)
//
// RQ-4 says an unknown per-member key round-trips verbatim. Under YAML 1.1 it
// does not. A hand-written `retired: no` under an undeclared key is captured by
// `AnyCodable.init(from:)` — which probes `Bool`, then `Int`, then `Double`,
// then `String`, taking the first success — as the boolean `false`, and
// re-emitted as `retired: false`. The author's spelling is destroyed on first
// write. `no` is also the Norwegian BCP-47 language tag, which is not a
// hypothetical for a cast list. A `code: 0755` is destroyed the same way, and
// worse: it comes back as `493`.
//
// Note that *declared* fields are almost entirely insulated from this: every
// `CastMember` field is `String?`, so nothing on that path ever asks Yams for a
// `Bool` or an `Int`. The one exception is `CastDocument.schemaVersion`, which
// is declared `Int` — see the rule below for what that costs.
//
// ## THE RULE: a plain scalar becomes a number only when that is provably
// ## lossless in spelling
//
// Implementing YAML 1.2 core *literally* would read `0755` as decimal 755. That
// is still a spelling loss, and RQ-4 asks for verbatim. So the rule this
// library applies is stronger and simpler than "be YAML 1.2 core":
//
//   A plain scalar is decoded as a number only when re-rendering the parsed
//   value reproduces the original characters exactly. Otherwise it stays a
//   `String`.
//
// In practice that reduces to: **a plain scalar becomes an `Int` when
// `String(intValue) == originalSpelling`, and otherwise stays a `String`.**
//
//   `180` -> Int 180        `String(180) == "180"`
//   `-5`  -> Int -5         exact
//   `0`   -> Int 0          exact
//   `0755`   -> String      `String(755) != "0755"` (and Yams would say 493)
//   `1_000`  -> String      `String(1000) != "1_000"`
//   `+5`     -> String      `String(5) != "+5"`
//   `12:34`  -> String      not a number in YAML 1.2 core at all
//   `1:00:00`-> String      same
//   `0b1011` -> String      binary is not YAML 1.2 core
//   `0o17`   -> String      1.2 core defines it; the spelling is not reproduced
//   `0x1f`   -> String      same
//
// ### Why NO floating-point spelling survives, and all of them stay strings
//
// This is not a policy choice, it is a measurement. Nothing on the emission
// path can reproduce a float's source spelling:
//
//   * `AnyCodable` stores its payload as JSON and, on the way out, probes `Int`
//     before `Double`. An integer-valued double therefore collapses: `1.0` was
//     captured as `Double 1.0`, stored as the JSON token `1`, and re-emitted as
//     `1`. So did `1.` and `1e3` (as `1` and `1000`).
//   * A non-integer-valued double is rendered by Yams' own
//     `formattedStringForCodable` (`Representer.swift:338-352`), which is
//     `String(format: "%.*g", DBL_DECIMAL_DIG, self)` with a `NumberFormatter`
//     fallback. `1.5` re-emitted as `1.5e+0`; `.5` re-emitted as `5e-1`.
//   * `.inf`, `-.inf`, `.nan`, and any overflowing literal such as `1e400` did
//     not merely lose their spelling — they made the whole decode *throw*,
//     because `JSONEncoder` refuses to encode a non-finite `Double` and
//     `AnyCodable.init(from:)` does not guard that `try`. A legal YAML document
//     was unreadable.
//
// Since no float spelling is reproducible, the lossless test is never satisfied
// by a float, and every plain float-shaped scalar is kept as a `String`. That
// also turns the three throwing cases above into ordinary strings.
//
// ## How the narrowing is implemented — TWO DIFFERENT LEVERS
//
// `Resolver([.merge])` at `Yams/Sources/Yams/Decoder.swift:147` does NOT do it,
// and the comment that used to claim otherwise was wrong. That resolver governs
// a node's *resolved* tag, and the two constructors this library must steer
// gate on two different things:
//
//   * `Bool.construct` gates on the node's *raw tag* —
//     `if scalar.tag.name == .str { return nil }` (`Constructor.swift:154-157`).
//     An unquoted plain scalar's raw tag is `.implicit`, so it sails past the
//     guard into a YAML 1.1 boolean switch. **Lever: stamp an explicit `.str`
//     raw tag.**
//   * `FixedWidthInteger.private_construct` and the `FloatingPoint` constructor
//     gate ONLY on the node's *style* —
//     `guard scalar.style == .any || scalar.style == .plain else { return nil }`
//     (`Constructor.swift:290-292` and `267-269`). **They never look at the tag
//     at all**, so retagging a numeric scalar `.str` does exactly nothing;
//     `0755` still came back as `493` with the `.str` tag on it. **Lever: set
//     the style to `.singleQuoted`.**
//
// So `decodeYAML` parses to a `Node` tree and walks it once, applying whichever
// lever the node needs. See `narrowingPlainScalarsToReadDialect(in:)`. The
// numeric branch sets *both* — `.str` to state the intent, `.singleQuoted`
// because that is what actually works today — and the "would Yams make a number
// of this?" question is answered by calling Yams' own public `Int.construct` /
// `Double.construct`, so this file cannot drift from the rules it is narrowing.
//
// ## What the pass covers, and what it deliberately does not
//
// COVERED: plain (unquoted), untagged scalars anywhere in the tree — mapping
// keys, mapping values, sequence elements, at any depth.
//
// NOT COVERED, ON PURPOSE:
//
//   * Quoted scalars. `'no'` and `'0755'` are already strings; their style and
//     value are left exactly as parsed.
//   * Explicitly tagged scalars. `!!bool no` and `!!int 0755` are the author
//     saying what they mean, and an explicit tag outranks a schema default.
//   * Null resolution. YAML 1.1 and YAML 1.2 core agree closely enough on
//     `null` / `Null` / `NULL` / `~` / empty, and `AnyCodable` already handles
//     null correctly, so nothing here touches it. This is also why the numeric
//     branch is fenced behind a leading-character pre-filter: `NSNull.construct`
//     requires style `.plain` exactly (`Constructor.swift:419`), so restyling a
//     null spelling would break null. No null spelling begins with a digit,
//     sign, or `.`, and the pre-filter enforces that structurally.
//   * Timestamps. `2026-08-01` was already a `String` on this path and stays
//     one; `Date` is not in `AnyCodable`'s probe chain.
//
// ## HONEST LIMITATION: this does not restore byte-verbatim round-tripping
//
// It restores the *value*, not the *bytes*. A bare `mood: no` is now captured
// as the string `"no"` and a bare `mood: 0755` as the string `"0755"` — but the
// emitter must quote a string that would otherwise re-resolve as a boolean or a
// number, so they come back out as `mood: 'no'` and `mood: '0755'`. The
// spelling survives; the plain style does not, and cannot. A genuinely numeric
// `count: 180` is unaffected and still re-emits bare, as `count: 180`.
//
// Sorties 13/14: a pinned fixture containing a bare `no`/`yes`/`on`/`off`, or a
// bare `0755`/`1_000`/`12:34`/`1.5`, under an undeclared key still fails a
// SHA-256 byte gate on its first pass. Write those quoted in the fixture. What
// changed is that the *meaning* and the *digits* no longer flip, which is what
// RQ-4 was actually asking for.
//
// One cost, stated plainly: `CastDocument.schemaVersion` is declared `Int`, so
// `schemaVersion: 01` — which YAML 1.1 read as 1 — is now a `String` and fails
// to decode as an `Int`. `schemaVersion: 1` is unaffected. Refusing a padded
// version number is the correct trade for never silently rewriting one.

/// The complete YAML 1.2 core-schema boolean set — six spellings, exact case.
///
/// Anything outside this set is a string in YAML 1.2 core, no matter what
/// YAML 1.1 thought of it. Note this is deliberately case-*sensitive*: `tRue`
/// is a boolean under YAML 1.1 (Yams lowercases before matching) and a string
/// under YAML 1.2 core, and this library follows YAML 1.2 core.
private let yaml12CoreBooleanSpellings: Set<String> = [
  "true", "True", "TRUE", "false", "False", "FALSE",
]

/// Every scalar YAML 1.1 resolves to a boolean, lowercased.
///
/// `Bool.construct` matches on `scalar.string.lowercased()`
/// (`Constructor.swift:158-166`), so lowercasing the candidate is what makes
/// this a faithful mirror of the set Yams will actually accept rather than a
/// hand-listed sample of it. `y` and `n` are in YAML 1.1's boolean production
/// but absent from Yams' switch; they are listed anyway so that a Yams release
/// which adds them cannot silently reintroduce the bug this pass exists to fix.
private let yaml11BooleanSpellingsLowercased: Set<String> = [
  "true", "false", "yes", "no", "on", "off", "y", "n",
]

/// The only characters a YAML number — in any dialect Yams implements — can
/// begin with.
///
/// This is a cheap pre-filter in front of the numeric branch, and it is also a
/// safety fence. `NSNull.construct` accepts a scalar only when its style is
/// exactly `.plain` (`Constructor.swift:419`), so restyling `null` / `Null` /
/// `NULL` / `~` / the empty scalar would silently turn a null into the string
/// that spells it. None of those begin with a character in this set, and the
/// `guard` that uses it is what makes "this pass cannot touch null" a
/// structural property rather than a promise.
private let numericLeadingCharacters: Set<Character> = [
  "+", "-", ".", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
]

/// Returns `node` with every plain scalar that YAML 1.1 would type differently
/// from this library's dialect neutralized, at every depth.
///
/// Booleans outside the YAML 1.2 core set are retagged `.str`; numbers whose
/// spelling would not survive a round trip are restyled `.singleQuoted` so that
/// Yams' numeric constructors decline them and they fall through to `String`.
/// See the dialect comment block above for why those are two different levers.
///
/// One recursive descent, each node visited exactly once, no rescans. The
/// index ranges below are `Range<Int>` rather than `node.indices` on purpose:
/// `DefaultIndices` holds a copy of the collection it indexes, which would
/// force a copy-on-write of the whole mapping on every single element
/// assignment and turn this walk quadratic.
private func narrowingPlainScalarsToReadDialect(in node: Node) -> Node {
  switch node {
  case .scalar(var scalar):
    // `.implicit` means "no explicit tag in the source". `.plain` means
    // "unquoted"; libyaml also reports `.any` for a scalar it did not style,
    // and Yams' own numeric constructors accept both, so this matches.
    //
    // The comparison is `== Tag.implicit` rather than `.tag.name == .implicit`
    // because `Tag.name` is internal to Yams. `Tag`'s public `==` compares
    // exactly that name, so this is the same test by a supported route.
    guard scalar.tag == Tag.implicit,
      scalar.style == .plain || scalar.style == .any
    else {
      return node
    }

    let spelling = scalar.string

    // --- Booleans (Sortie 8b). Settled; do not re-litigate the six spellings.
    if !yaml12CoreBooleanSpellings.contains(spelling),
      yaml11BooleanSpellingsLowercased.contains(spelling.lowercased())
    {
      // `copy(with:)` rather than a fresh `Tag`, so the node keeps the resolver
      // and constructor the parser gave it and only the name changes. Assigning
      // `scalar.string` would be a bug here: its `didSet` resets the tag to
      // `.implicit` and would undo this on the spot.
      scalar.tag = scalar.tag.copy(with: .str)
      return .scalar(scalar)
    }

    // --- Numbers (Sortie 9a). A boolean is never also a number, so reaching
    // here means the boolean branch declined and the two cannot collide.
    guard let lead = spelling.first, numericLeadingCharacters.contains(lead) else {
      return node
    }

    // Yams answers "is this a number?" for us. Asking it directly — rather than
    // re-deriving its rules here — is what keeps this pass correct across a
    // Yams bump that widens or narrows them, and it is why sexagesimal, `0b`,
    // `0o`, `0x`, `_` separators, and the leading-zero octal form need no cases
    // of their own. Both constructors require the style this `guard` already
    // established, so both calls are meaningful.
    let integer = Int.construct(from: scalar)

    // THE LOSSLESS TEST. `String(integer)` is the exact text this value would
    // be written back as, so equality here is a proof — not an approximation —
    // that decoding the number changes neither the value nor the characters.
    if let integer, String(integer) == spelling {
      return node
    }

    // Not a lossless integer. If Yams would still make a number of it, it must
    // be stopped; if Yams would not, it is already a `String` and is left
    // exactly as parsed. `Double.construct` is only consulted when the integer
    // route already failed, which is also the order `AnyCodable` probes in.
    guard integer != nil || Double.construct(from: scalar) != nil else {
      return node
    }

    // The tag states the intent and would be honored by any constructor that
    // consulted it. The style is what actually works: the integer and floating-
    // point constructors gate on style alone and never read the tag, so this
    // assignment — and only this assignment — is what makes `0755` a string.
    scalar.tag = scalar.tag.copy(with: .str)
    scalar.style = .singleQuoted
    return .scalar(scalar)

  case .mapping(var mapping):
    for index in mapping.startIndex..<mapping.endIndex {
      let pair = mapping[index]
      mapping[index] = (
        key: narrowingPlainScalarsToReadDialect(in: pair.key),
        value: narrowingPlainScalarsToReadDialect(in: pair.value)
      )
    }
    return .mapping(mapping)

  case .sequence(var sequence):
    for index in sequence.startIndex..<sequence.endIndex {
      sequence[index] = narrowingPlainScalarsToReadDialect(in: sequence[index])
    }
    return .sequence(sequence)

  case .alias:
    // An alias carries no scalar of its own; the node it points at was already
    // visited where it was defined.
    return node
  }
}

/// Deserializes a `Codable` value from a YAML document.
///
/// This is the single ingest path for everything this library reads, and the
/// one place the YAML 1.2 core-schema narrowing described above is applied.
/// Anything that decodes YAML by another route gets YAML 1.1 and its booleans;
/// that is a second reason — beyond D-1's swappability argument — that this is
/// the only file permitted to `import Yams`.
///
/// - Parameters:
///   - type: The type to decode.
///   - yaml: The YAML document text. For a `CAST.md` this is the front matter
///     only, already split from the body by the caller.
/// - Returns: The decoded value.
/// - Throws: ``CastParseError`` unchanged when the decoded type raised one, and
///   otherwise a `DecodingError`.
///
///   **The ``CastParseError`` passthrough is load-bearing and is the one place
///   this function deliberately does *not* reproduce Yams.**
///   `YAMLDecoder.processYamlNode` (`Yams/Sources/Yams/Decoder.swift:141-166`)
///   catches `DecodingError` and wraps everything else in
///   `DecodingError.dataCorrupted`, reachable only through `underlyingError`.
///   Applied here that would take the four typed failures
///   `CastDocument.init(from:)` raises — `unsupportedSchemaVersion`,
///   `missingTypeCast`, `missingCastKey`, `missingCharacter` — and bury each of
///   them inside a "The given data was not valid YAML." that says nothing about
///   what was actually wrong. RQ-12 exists so a caller can tell those apart, so
///   they travel out of here as themselves. Genuine YAML and decoding failures
///   are still `DecodingError`; `CastMarkdownParser` is what maps those onto
///   ``CastParseError/invalidYAML(_:)``.
func decodeYAML<Value: Decodable>(_ type: Value.Type, from yaml: String) throws -> Value {
  // Same rule as the encoder: constructed per call, never stored. `YAMLDecoder`
  // is also a non-`Sendable` `public class` with mutable options.
  let decoder = YAMLDecoder()

  // Explicit rather than `.default`, which resolves by inspecting the string.
  // Every document this library handles is UTF-8, and saying so removes a
  // branch that could behave differently on differently-encoded input.
  decoder.options.encoding = .utf8

  // Everything below reproduces `YAMLDecoder.processYamlNode`
  // (`Yams/Sources/Yams/Decoder.swift:141-166`) with the dialect-narrowing walk
  // spliced between compose and decode. Going through `decode(_:from: String)`
  // instead would give the walk nothing to narrow — that overload composes and
  // decodes in one step and never hands out the `Node`.
  //
  // `Resolver.basic.appending(.merge)` is `Resolver([.merge])`; Yams' array
  // initializer is internal, and `basic` is the empty-rule resolver, so the two
  // are the same object graph by a public route. Keeping the resolver identical
  // matters: merge keys (`<<`) must still resolve, and nothing else should.
  let parser = try Parser(
    yaml: yaml,
    resolver: Resolver.basic.appending(.merge),
    encoding: .utf8)

  do {
    // The parser owns the `Anchor` objects; `Node` refers to them weakly. It
    // has to outlive the decode or an anchored document loses its anchors.
    return try withExtendedLifetime(parser) {
      let parsed = try parser.singleRoot() ?? Node("")
      return try decoder.decode(Value.self, from: narrowingPlainScalarsToReadDialect(in: parsed))
    }
  } catch let error as CastParseError {
    // Ahead of the `DecodingError` clause on purpose. `CastParseError` is not a
    // `DecodingError`, so without this it would fall to the wrapping clause
    // below and reach the caller as `dataCorrupted` with the real cause hidden
    // in `underlyingError`. See this function's `Throws:` note.
    throw error
  } catch let error as DecodingError {
    throw error
  } catch {
    throw DecodingError.dataCorrupted(
      .init(
        codingPath: [],
        debugDescription: "The given data was not valid YAML.",
        underlyingError: error))
  }
}
