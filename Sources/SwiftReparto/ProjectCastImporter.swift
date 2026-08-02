//
//  ProjectCastImporter.swift
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

// This file reaches YAML through `YAMLCoding.swift` and never imports Yams
// (D-1), and it declares no dependency on any first-party org package
// (RQ-INV-1) — see this type's documentation for why that is the single most
// important fact about this file.

/// Reads the `cast:` key out of a `PROJECT.md` and hands back a
/// ``CastDocument`` (D-4).
///
/// ```swift
/// let importer = ProjectCastImporter()
/// let document = try importer.importCast(fileURL: projectURL)
/// try CastMarkdownParser().write(
///   document: document,
///   to: projectURL.deletingLastPathComponent().appending(path: "CAST.md"))
/// ```
///
/// ## What this type owns, and the one thing it must never do
///
/// **Reparto imports the cast data; it does not own, resolve, or write
/// `PROJECT.md`.** That sentence is the whole of the boundary, and RQ-INV-3 is
/// narrowed to exactly it: this type may read the `cast:` key out of a
/// `PROJECT.md` it is handed, and nothing else. It reads no `title`, no `tts`,
/// no `episodes_index`, no `variants`, no `languages` — the front-matter
/// container below declares one key, so no other key can reach the result even
/// by accident. And it **never writes that file**: import is read-only with
/// respect to its source, there is no code path here that opens a file for
/// writing, and removing a now-migrated `cast:` block from a `PROJECT.md` is
/// not this library's job and not any caller's (D-13).
///
/// ## The dependency that must never be added (RQ-INV-1)
///
/// A parser for `PROJECT.md` front matter already exists — in the package that
/// owns `PROJECT.md`. Calling it from here would add a first-party dependency
/// to this manifest and close a package-level cycle, which SwiftPM detects at
/// manifest load and which no target-level arrangement can escape. That cycle
/// is the specific thing this library exists to make impossible, so this type
/// decodes the front matter itself, through ``decodeYAML(_:from:)``, and always
/// will. If a future edit here starts with "we could just reuse…", it is this
/// paragraph the edit is proposing to spend.
///
/// ## One decoder, not two (D-4)
///
/// Members are decoded through ``CastMember``'s own `init(from:)` — the same
/// one ``CastMarkdownParser/parse(content:)`` uses. Every RQ-3 leniency (the
/// legacy `voiceDescription` key, a provider mapped to a bare scalar) and every
/// RQ-4 guarantee (undeclared keys such as `bio:`, and a nested `appearance:`
/// block, preserved in ``CastMember/extraKeys``) therefore applies identically
/// on this path. A second decoder would drift from the first, and the drift
/// would show up as data loss on someone's roster.
///
/// ## What the produced document does *not* carry
///
/// - **No body.** ``CastDocument/body`` is the empty string. A `PROJECT.md`'s
///   markdown is project prose, not cast prose, and RQ-8 forbids this library
///   from generating body content of its own. The human writes the `# Cast`
///   narrative into the new `CAST.md` afterward.
/// - **No `type: cast`.** It is not required on input, because a `PROJECT.md`
///   correctly declares `type: project`. Only a well-formed front-matter block
///   carrying a `cast:` key is required. The emitted document declares
///   `type: cast`, because by then it *is* one.
public struct ProjectCastImporter: Sendable {

  /// Create an importer.
  ///
  /// Stateless, like ``CastMarkdownParser`` and for the same reason: holding a
  /// YAML coder would forfeit `Sendable`, since Yams' coders are non-`Sendable`
  /// classes (RQ-15). ``YAMLCoding`` constructs one per call instead.
  public init() {}

  // MARK: - Importing

  /// Imports the `cast:` block out of a `PROJECT.md`'s contents.
  ///
  /// - Important: **This entry point does not normalize paths, and that is
  ///   deliberate (D-7)** — it matches ``CastMarkdownParser/parse(content:)``
  ///   exactly. A bare `String` has no directory, so there is nothing to
  ///   relativize against and this method will not invent one. Callers that
  ///   know where the `PROJECT.md` lives should use ``importCast(fileURL:)``.
  ///
  /// - Parameter content: The whole `PROJECT.md`: a leading `---`, YAML front
  ///   matter, a closing `---`, and then markdown. The markdown is not read.
  /// - Returns: A ``CastDocument`` holding the imported roster, an empty
  ///   ``CastDocument/body``, and ``CastSchemaVersion/current``.
  /// - Throws: ``CastParseError/noFrontMatter`` when the content carries no
  ///   delimited block; ``CastParseError/invalidYAML(_:)`` when it carries one
  ///   that will not parse; ``CastParseError/missingCastKey`` when the front
  ///   matter is well-formed but declares no `cast:` key — **a typed error, not
  ///   an empty roster**; and ``CastParseError/missingCharacter(index:)`` for a
  ///   member with no `character` field.
  public func importCast(content: String) throws -> CastDocument {
    // UTF-8 bytes, not `Character`s — the same reason `CastMarkdownParser`
    // does it, and now the same code: `splitFrontMatter(_:)` is shared with
    // the parser (Sortie 12a) so the delimiter rules cannot drift between
    // import and parse. The body range it computes is discarded below; an
    // imported document's body is the empty string by design (see this
    // type's documentation).
    let bytes = Array(content.utf8)

    guard let split = splitFrontMatter(bytes) else {
      throw CastParseError.noFrontMatter
    }

    let frontMatter = String(decoding: bytes[split.frontMatter], as: UTF8.self)

    let block: ProjectCastBlock
    do {
      block = try decodeYAML(ProjectCastBlock.self, from: frontMatter)
    } catch let error as CastParseError {
      // Rethrown unchanged, for the same reason `CastMarkdownParser` does it:
      // `ProjectCastBlock.init(from:)` raises two `CastParseError` cases
      // itself, and collapsing them into `.invalidYAML` here would report "not
      // valid YAML" for front matter that parsed perfectly.
      throw error
    } catch {
      throw CastParseError.invalidYAML(failureMessage(for: error))
    }

    // The schema version is stamped, not inherited: a `PROJECT.md` has no
    // `schemaVersion` key and never will, so the first write of an imported
    // roster is a versioned `CAST.md` (D-5). The body is empty by design — see
    // this type's documentation.
    return CastDocument(
      cast: block.cast,
      body: "",
      schemaVersion: CastSchemaVersion.current)
  }

  /// Reads a `PROJECT.md` from disk and imports its `cast:` block, normalizing
  /// paths against the file's own directory (D-7).
  ///
  /// This is one of only two places in the library that touch the filesystem —
  /// the other is ``CastMarkdownParser/parse(fileURL:)`` — and each reads
  /// exactly the one URL it is handed. Nothing here scans a directory, follows
  /// a reference, or checks whether any path in the roster exists (RQ-7). **And
  /// nothing here writes**: the file this method is pointed at is left byte-for
  /// byte as it was found, which is asserted by a SHA-256 test.
  ///
  /// Relativization runs against `fileURL.deletingLastPathComponent()` through
  /// the same shared ``relativizingPaths(in:to:)`` the parser uses — not a copy
  /// of it. Because a `CAST.md` is written beside its `PROJECT.md`, the two
  /// files share a base directory, so a path already relative in the
  /// `PROJECT.md` is already relative to the `CAST.md` and comes through
  /// untouched. The pass exists for the absolute-path case, and it runs
  /// unconditionally so that there is one rule rather than a rule plus an
  /// exception.
  ///
  /// - Parameter fileURL: The `PROJECT.md` to read.
  /// - Returns: The imported document.
  /// - Throws: A ``CastParseError`` for anything wrong with the front matter. A
  ///   file that cannot be read or is not UTF-8 throws Foundation's own error
  ///   instead, unchanged and untranslated.
  public func importCast(fileURL: URL) throws -> CastDocument {
    let content = try String(contentsOf: fileURL, encoding: .utf8)
    let document = try importCast(content: content)
    return relativizingPaths(in: document, to: fileURL.deletingLastPathComponent())
  }

}

// MARK: - The one key this library reads out of a `PROJECT.md`

/// The `cast:` key of a `PROJECT.md`'s front matter, and nothing else (D-4).
///
/// **The narrowness is the point, and it is structural rather than a promise.**
/// There is exactly one case in ``CodingKeys``, so no other front-matter key
/// can reach an imported document even by accident — not `title`, not `tts`,
/// not `episodes_index`, not a key someone adds to that schema next year. A
/// reviewer checking that this library reads only `cast:` reads one enum.
///
/// Note in particular that there is no undeclared-key sweep here, deliberately.
/// ``CastMember`` has one, because RQ-4 requires per-member keys to survive a
/// round trip. A *project*-level key has no such promise attached and no place
/// in a cast document, so it is not captured, not stored, and not re-emitted.
private struct ProjectCastBlock: Decodable {

  /// The imported roster, in document order.
  let cast: [CastMember]

  enum CodingKeys: String, CodingKey {
    case cast
  }

  /// Decodes the roster.
  ///
  /// `type: cast` is **not** required, because a `PROJECT.md` declares
  /// `type: project` and refusing it would make import impossible. The `cast:`
  /// key is required, and its absence is
  /// ``CastParseError/missingCastKey`` — a typed error rather than an empty
  /// roster, which is the distinction RQ-12 exists to preserve.
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    guard container.contains(.cast), try !container.decodeNil(forKey: .cast) else {
      throw CastParseError.missingCastKey
    }

    // Member by member rather than as one array, so the index of a bad entry is
    // known when it fails — an array-at-a-time decode discards exactly the
    // number `missingCharacter(index:)` needs to point at the offending entry.
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
  }

  /// Recognizes a missing `character` field and reports which member lacked it.
  ///
  /// Only that one failure is translated; every other `DecodingError` is
  /// returned unchanged, because flattening them all would report the wrong
  /// cause for a type mismatch three levels down.
  private static func translate(_ error: DecodingError, atMemberIndex index: Int) -> Error {
    guard
      case .keyNotFound(let key, _) = error,
      key.stringValue == CastMember.CodingKeys.character.stringValue
    else {
      return error
    }
    return CastParseError.missingCharacter(index: index)
  }
}
