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

/// Deserializes a `Codable` value from a YAML document.
///
/// This is the single ingest path for everything this library reads.
///
/// ## The plain-scalar behavior this depends on (AR-2)
///
/// `YAMLDecoder` builds its parser as `Resolver([.merge])` rather than
/// `Resolver.default` (`Yams/Sources/Yams/Decoder.swift:147`). The consequence
/// is the one this library cares about most: the `Codable` path performs no
/// implicit YAML 1.1 type resolution, so a plain scalar arrives tagged `.str`
/// and the destination Swift type decides what it is. `language: no` therefore
/// decodes to the `String` `"no"` and not to `false`.
///
/// That behavior is deliberate upstream but undocumented, so it is pinned by
/// regression test rather than trusted. See `YAMLCodingTests`.
///
/// - Parameters:
///   - type: The type to decode.
///   - yaml: The YAML document text. For a `CAST.md` this is the front matter
///     only, already split from the body by the caller.
/// - Returns: The decoded value.
/// - Throws: Whatever the decoded type throws — note that `CastDocument`
///   throws `CastParseError` directly, not `DecodingError` — or a
///   `DecodingError` for malformed YAML.
func decodeYAML<Value: Decodable>(_ type: Value.Type, from yaml: String) throws -> Value {
  // Same rule as the encoder: constructed per call, never stored. `YAMLDecoder`
  // is also a non-`Sendable` `public class` with mutable options.
  let decoder = YAMLDecoder()

  // Explicit rather than `.default`, which resolves by inspecting the string.
  // Every document this library handles is UTF-8, and saying so removes a
  // branch that could behave differently on differently-encoded input.
  decoder.options.encoding = .utf8

  return try decoder.decode(Value.self, from: yaml)
}
