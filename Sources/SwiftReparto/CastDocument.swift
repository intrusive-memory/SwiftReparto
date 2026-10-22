//
//  CastDocument.swift
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

/// A whole `CAST.md` file: its roster, its schema version, and the markdown
/// body that follows the front matter (RQ-9).
///
/// This is the unit of read-modify-write. Consumers mutate ``cast`` and leave
/// ``body`` alone.
///
/// ## `Codable` here means *front matter*, and only front matter
///
/// **``body`` is deliberately not part of this type's encoded form.** A
/// `CAST.md` is a YAML front-matter block followed by markdown; the body lives
/// *after* the closing `---`, not inside the block. If ``body`` were an
/// encodable key it would be written into the front matter as a `body:` scalar
/// — a mangled, re-indented, line-ending-normalized copy of the very bytes RQ-8
/// requires be preserved exactly.
///
/// So the contract is:
///
/// - ``encode(to:)`` writes exactly three keys, in this order: `type`,
///   `schemaVersion`, `cast`. That order is fixed here, at the `encode(to:)`
///   layer, which is what lets the YAML encoder run with key sorting off and
///   still produce byte-stable output for RQ-11's SHA-256 gate (D-12).
/// - ``init(from:)`` reads those same three keys and sets ``body`` to the empty
///   string. **The decoder does not know where the body is and must not
///   guess.** Whoever split the front matter off owns the body: it assigns the
///   byte-exact remainder after decoding.
///
/// A consequence worth stating plainly: round-tripping a `CastDocument` through
/// a general-purpose `Codable` encoder and decoder does *not* preserve
/// ``body``. Round-trip identity is defined on the markdown (RQ-11), where the
/// body is carried outside the front matter and copied verbatim — not on this
/// conformance.
///
/// ## The version travels one way
///
/// ``schemaVersion`` records what the *source document* declared, which is
/// provenance, not a switch. Emission always stamps
/// ``CastSchemaVersion/current`` (D-5): a document that arrived unversioned
/// leaves versioned, which is the entire mechanism that lets hand-written
/// legacy files keep working and normalize on their first write. Nothing needs
/// to remember to stamp it, because nothing is given the option not to.
///
/// ## Example
///
/// ```swift
/// var document = CastDocument(
///   cast: [CastMember(character: "NARRATOR")],
///   body: "## Notes\n\nRecorded in one take.\n"
/// )
/// document.cast[0].actor = "Tom Stovall"
/// ```
public struct CastDocument: Codable, Sendable, Equatable {

  /// The value the `type:` front-matter key must carry for a document to be a
  /// cast document (RQ-1).
  ///
  /// Declared once, read by the decoder and written by the encoder, so the
  /// literal cannot drift between the two.
  public static let documentType: String = "cast"

  /// The roster, in document order.
  ///
  /// An empty array is a valid, fully-parsed document with no members — it is
  /// never a signal that parsing failed. See `CastParseError.swift` for why
  /// that distinction is load-bearing (RQ-12).
  public var cast: [CastMember]

  /// The markdown following the front matter, byte-for-byte (RQ-8).
  ///
  /// Line endings, trailing whitespace, and the presence or absence of a final
  /// newline are all content here, not formatting to be tidied. Nothing in this
  /// library trims, reflows, or normalizes it, and it is never emitted into the
  /// front matter — see this type's documentation.
  public var body: String

  /// The schema version the source document declared (D-12).
  ///
  /// ``CastSchemaVersion/unversioned`` when the document declared none, which
  /// is legacy-but-valid rather than invalid (D-5). This value is *not* what
  /// gets emitted: ``encode(to:)`` always writes
  /// ``CastSchemaVersion/current``.
  public var schemaVersion: Int

  /// Whether this document arrived carrying no schema version at all.
  ///
  /// The observable form of the legacy sentinel: a caller that wants to warn
  /// "this file predates versioning and will be normalized on save" asks here
  /// rather than comparing integers.
  public var isUnversioned: Bool {
    CastSchemaVersion.isUnversioned(schemaVersion)
  }

  /// Create a cast document.
  ///
  /// - Parameters:
  ///   - cast: The roster. Defaults to empty.
  ///   - body: The markdown following the front matter. Defaults to empty.
  ///   - schemaVersion: The declared schema version. Defaults to
  ///     ``CastSchemaVersion/current``, because a document constructed in
  ///     memory is being written by this build. Pass
  ///     ``CastSchemaVersion/unversioned`` to model a legacy document.
  public init(
    cast: [CastMember] = [],
    body: String = "",
    schemaVersion: Int = CastSchemaVersion.current
  ) {
    self.cast = cast
    self.body = body
    self.schemaVersion = schemaVersion
  }

  // MARK: - Codable

  /// The front-matter keys, in emission order.
  ///
  /// Declaration order is the emission order and is load-bearing: `type`,
  /// `schemaVersion`, `cast`. Lexicographic sorting would yield `cast`,
  /// `schemaVersion`, `type`, which is why the YAML layer must not sort keys
  /// (D-12).
  ///
  /// There is no `body` case, and adding one would write the markdown body
  /// into the front matter. See this type's documentation.
  enum CodingKeys: String, CodingKey {
    case type
    case schemaVersion
    case cast
  }

  /// Decodes the front matter of a cast document.
  ///
  /// Checks run in a deliberate order — version, then type, then roster — so a
  /// document from a future schema is refused before this build tries to
  /// interpret any key whose meaning that schema may have changed.
  ///
  /// ``body`` is set to the empty string; the caller that split the front
  /// matter assigns the real bytes.
  ///
  /// - Throws: ``CastParseError/unsupportedSchemaVersion(found:supported:)``,
  ///   ``CastParseError/missingTypeCast``, ``CastParseError/missingCastKey``,
  ///   ``CastParseError/missingCharacter(index:)``, or
  ///   ``CastParseError/invalidRole(index:value:)``. Any other failure
  ///   surfaces as the underlying `DecodingError`. A caller that maps decode
  ///   failures onto ``CastParseError/invalidYAML(_:)`` must let
  ///   ``CastParseError`` values through first — they are more specific than
  ///   the mapping, not instances of it.
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    // 1. Version first (D-12). A newer document may have redefined every key
    //    below this line, so nothing below this line runs until the version is
    //    known to be readable. Absent means legacy, not invalid (D-5).
    let declaredVersion =
      try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
      ?? CastSchemaVersion.unversioned
    try CastSchemaVersion.validate(declaredVersion)
    schemaVersion = declaredVersion

    // 2. RQ-1: the document must say what it is. A `PROJECT.md` carrying a
    //    `cast:` key is not a cast document, and this is what stops SwiftReparto
    //    from rewriting one as though it were.
    let declaredType = try container.decodeIfPresent(String.self, forKey: .type)
    guard declaredType == Self.documentType else {
      throw CastParseError.missingTypeCast
    }

    // 3. RQ-1: a `cast:` key must be present. Present-and-empty is a valid
    //    document with no members; absent or null is not a roster at all.
    guard container.contains(.cast), try !container.decodeNil(forKey: .cast) else {
      throw CastParseError.missingCastKey
    }

    // Decode member by member rather than as one array so the index of a bad
    // entry is known when it fails. `missingCharacter(index:)` exists to point
    // at the offending member, and an array-at-a-time decode discards exactly
    // the number needed to do that.
    var members: [CastMember] = []
    var memberContainer = try container.nestedUnkeyedContainer(forKey: .cast)
    var index = 0
    while !memberContainer.isAtEnd {
      do {
        members.append(try memberContainer.decode(CastMember.self))
      } catch let error as DecodingError {
        throw Self.translate(error, atMemberIndex: index)
      }
      index += 1
    }
    cast = members

    // The body is not front matter and the decoder cannot see it (see the type
    // documentation). Whoever split the document assigns the real bytes.
    body = ""
  }

  /// Encodes the front matter of a cast document.
  ///
  /// Writes `type`, ``CastSchemaVersion/current``, and `cast`, in that order,
  /// and writes ``body`` nowhere. The version stamped is always the current one
  /// regardless of what ``schemaVersion`` holds (D-5) — that is what normalizes
  /// a legacy document on its first write.
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(Self.documentType, forKey: .type)
    try container.encode(CastSchemaVersion.current, forKey: .schemaVersion)
    try container.encode(cast, forKey: .cast)
  }

  /// Recognizes a missing `character` field or an unknown `role` and reports
  /// which member it was. See `translateMemberDecodingError(_:atMemberIndex:)`.
  private static func translate(_ error: DecodingError, atMemberIndex index: Int) -> Error {
    translateMemberDecodingError(error, atMemberIndex: index)
  }
}
