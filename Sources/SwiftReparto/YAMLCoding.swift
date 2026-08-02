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
// THIS LIBRARY READS YAML 1.2 CORE-SCHEMA SEMANTICS THROUGH A YAML 1.1 PARSER.
//
// libyaml — and therefore Yams — implements YAML 1.1, whose implicit typing
// rules say that the plain scalars `yes`, `no`, `on`, `off`, `y`, and `n` are
// booleans. YAML 1.2's core schema narrowed that set to exactly six spellings:
// `true`, `True`, `TRUE`, `false`, `False`, `FALSE`. Everything else is a
// string.
//
// ## Why the narrower dialect is the one we want (RQ-4)
//
// RQ-4 says an unknown per-member key round-trips verbatim. Under YAML 1.1 it
// does not. A hand-written `retired: no` under an undeclared key is captured by
// `AnyCodable.init(from:)` — which probes `Bool` before `String` and takes the
// first success — as the boolean `false`, and re-emitted as `retired: false`.
// The author's spelling is destroyed on first write. `no` is also the Norwegian
// BCP-47 language tag, which is not a hypothetical for a cast list.
//
// Note that *declared* fields were never exposed to this: every `CastMember`
// field is `String?`, so nothing on that path ever asks Yams for a `Bool`. It
// is only the undeclared-key path, where there is no destination type to steer
// the decode, that YAML 1.1 reaches.
//
// ## How the narrowing is implemented
//
// `Resolver([.merge])` at `Yams/Sources/Yams/Decoder.swift:147` does NOT do it,
// and the comment that used to claim otherwise was wrong. That resolver governs
// a node's *resolved* tag; `Bool.construct` gates on the node's *raw* tag —
// `if scalar.tag.name == .str { return nil }` (`Constructor.swift:154-157`) —
// and an unquoted plain scalar's raw tag is `.implicit`, so it sails past the
// guard into a YAML 1.1 boolean switch over `true/yes/on` and `false/no/off`.
//
// So `decodeYAML` parses to a `Node` tree, walks it once, and stamps an
// explicit `.str` raw tag onto every plain scalar that YAML 1.1 would call a
// boolean and YAML 1.2's core schema would not. `Bool.construct`'s own guard
// then does the rest. See `retaggingPlainYAML11Booleans(in:)`.
//
// ## What the pass covers, and what it deliberately does not
//
// COVERED: plain (unquoted), untagged scalars anywhere in the tree — mapping
// keys, mapping values, sequence elements, at any depth.
//
// NOT COVERED, ON PURPOSE:
//
//   * Quoted scalars. `'no'` is already a string; its style and value are left
//     exactly as parsed.
//   * Explicitly tagged scalars. `!!bool no` is the author saying "boolean",
//     and an explicit tag outranks a schema default.
//   * Null resolution. YAML 1.1 and YAML 1.2 core agree closely enough on
//     `null` / `Null` / `NULL` / `~` / empty, and `AnyCodable` already handles
//     null correctly, so nothing here touches it.
//   * YAML 1.1's *integer* extensions — sexagesimal (`12:34` -> 754) and the
//     bare-leading-zero octal form (`0755` -> 493). These are a real 1.1-vs-1.2
//     divergence and they DO reach `AnyCodable`, but by a different mechanism:
//     `Int.construct` gates on scalar *style*, not on the raw tag
//     (`Constructor.swift:290-294`), so retagging would not stop them anyway.
//     Left alone deliberately — narrowing the integer rules is a separate
//     decision from the boolean one, and it has not been made.
//
// ## HONEST LIMITATION: this does not restore byte-verbatim round-tripping
//
// It restores the *value*, not the *bytes*. A bare `mood: no` is now captured
// as the string `"no"` — but the emitter must quote a string that would
// otherwise re-resolve as a boolean, so it comes back out as `mood: 'no'`. The
// spelling survives; the quoting does not. Sorties 13/14: a pinned fixture
// containing a bare `no`/`yes`/`on`/`off` under an undeclared key still fails a
// SHA-256 byte gate on its first pass. Write it quoted in the fixture. What
// changed is that the *meaning* no longer flips, which is what RQ-4 was
// actually asking for.

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

/// Returns `node` with every YAML-1.1-only boolean plain scalar retagged
/// `.str`, at every depth.
///
/// One recursive descent, each node visited exactly once, no rescans. The
/// index ranges below are `Range<Int>` rather than `node.indices` on purpose:
/// `DefaultIndices` holds a copy of the collection it indexes, which would
/// force a copy-on-write of the whole mapping on every single element
/// assignment and turn this walk quadratic.
private func retaggingPlainYAML11Booleans(in node: Node) -> Node {
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
      scalar.style == .plain || scalar.style == .any,
      !yaml12CoreBooleanSpellings.contains(scalar.string),
      yaml11BooleanSpellingsLowercased.contains(scalar.string.lowercased())
    else {
      return node
    }

    // `copy(with:)` rather than a fresh `Tag`, so the node keeps the resolver
    // and constructor the parser gave it and only the name changes. Assigning
    // `scalar.string` would be a bug here: its `didSet` resets the tag to
    // `.implicit` and would undo this on the spot.
    scalar.tag = scalar.tag.copy(with: .str)
    return .scalar(scalar)

  case .mapping(var mapping):
    for index in mapping.startIndex..<mapping.endIndex {
      let pair = mapping[index]
      mapping[index] = (
        key: retaggingPlainYAML11Booleans(in: pair.key),
        value: retaggingPlainYAML11Booleans(in: pair.value)
      )
    }
    return .mapping(mapping)

  case .sequence(var sequence):
    for index in sequence.startIndex..<sequence.endIndex {
      sequence[index] = retaggingPlainYAML11Booleans(in: sequence[index])
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
  // (`Yams/Sources/Yams/Decoder.swift:141-166`) with the retagging walk spliced
  // between compose and decode. Going through `decode(_:from: String)` instead
  // would give the retagging pass nothing to retag — that overload composes and
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
      return try decoder.decode(Value.self, from: retaggingPlainYAML11Booleans(in: parsed))
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
