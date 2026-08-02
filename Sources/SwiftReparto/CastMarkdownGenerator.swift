//
//  CastMarkdownGenerator.swift
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
// (D-1), exactly like the parser it extends.

/// Emission: the exact inverse of `CastMarkdownParser`'s front-matter split.
///
/// **This is the only place in the ecosystem that serializes a `CAST.md`
/// (RQ-INV-2).** It lives in its own file but as an extension on
/// ``CastMarkdownParser``, because RQ-10 declares all four entry points on that
/// one type — a consumer holds one value and can both read and write with it.
///
/// ## Why this is an inversion and not a formatter
///
/// The parser's split is stated in `CastMarkdownParser.swift` as: the body is
/// every byte after the closing delimiter's line terminator. So emission is
/// `---` + LF, the front matter, `---` + LF, and then the body's bytes with
/// nothing done to them. There is no separator logic here, no blank line
/// inserted before or after the body, no trailing newline added to a body that
/// lacks one, and no trailing whitespace on either delimiter line. The parser
/// *tolerates* a trailing space after `---`; identity requires that this writer
/// never produce one.
///
/// ## Two normalizations happen, and both are deliberate
///
/// Emission is not a byte-copy of whatever was read — it is a byte-copy of the
/// *body*, and a fresh rendering of the front matter from the model. Two things
/// therefore change on a document's first write, by design:
///
/// - **The schema version is stamped** (D-5). `CastDocument.encode(to:)` always
///   writes ``CastSchemaVersion/current``, so a legacy document that declared
///   no version leaves carrying one. Nothing here has the option to skip it.
/// - **`voices` is written in the array form** (RQ-3). The decoder accepts
///   `voxalta: a.vox`; ``CastMember/voices`` is `[String: [String]]`, so a
///   scalar becomes a one-element array on the way in and there is no scalar
///   form left to emit on the way out.
///
/// Both are idempotent: applying them to an already-emitted document changes
/// nothing, which is what makes RQ-11's SHA-256 gate a fixed point rather than
/// a moving target.
///
/// ## No path logic, in either entry point (D-7)
///
/// Neither ``CastMarkdownParser/generate(document:)`` nor
/// ``CastMarkdownParser/write(document:to:)`` touches a path string. RQ-6's
/// "absolute paths decode but are never emitted" is satisfied at the *ingest*
/// boundary — `parse(fileURL:)` and the importer relativize against the
/// directory they were handed — so a document obtained from a file never holds
/// an absolute path in the first place.
///
/// Relativizing here instead is not an available alternative:
/// `generate(document:)` receives no URL and has no directory to relativize
/// against, so only `write` could do it, and then the two would emit different
/// bytes for the same document. RQ-11's gate asserts on `generate` — on the
/// string that never reaches disk — so the disagreement would be invisible to
/// the gate and visible only in the file. `write` is therefore `generate` plus
/// a write, with nothing in between.
extension CastMarkdownParser {

  // MARK: - Generating

  /// Renders a document as `CAST.md` text.
  ///
  /// ```swift
  /// let parser = CastMarkdownParser()
  /// var document = try parser.parse(fileURL: url)
  /// document.cast[0].actor = "Tom Stovall"
  /// let markdown = try parser.generate(document: document)
  /// ```
  ///
  /// - Parameter document: The document to render. Its
  ///   ``CastDocument/schemaVersion`` is *not* consulted — emission always
  ///   stamps ``CastSchemaVersion/current`` (D-5).
  /// - Returns: The whole file: `---`, the YAML front matter with keys in the
  ///   order `type`, `schemaVersion`, `cast` (D-12), `---`, and then
  ///   ``CastDocument/body`` byte-for-byte.
  /// - Throws: `EncodingError` if some value in the document cannot be
  ///   represented in YAML. A well-formed ``CastDocument`` cannot produce one:
  ///   every declared field is a `String`, a ``Gender``, or a collection of
  ///   those, and ``AnyCodable`` only ever holds what it decoded.
  public func generate(document: CastDocument) throws -> String {
    var frontMatter = try encodeYAML(document)

    // The closing delimiter must begin a line, and only the front matter's last
    // byte can say whether it already does.
    //
    // This is the one piece of joining this function performs, and it is a
    // guard rather than a formatting pass: nothing is trimmed, no blank line is
    // collapsed, and a front matter already ending in a newline is passed
    // through untouched. libyaml terminates its last line in every case this
    // library can produce, so in practice this appends nothing — it is here so
    // that a Yams change cannot silently emit `cast: []---` and turn a
    // well-formed document into one with no front matter at all.
    if !frontMatter.hasSuffix("\n") {
      frontMatter.append("\n")
    }

    // Exactly the parser's split, run backwards. `body` is concatenated raw:
    // its CRLFs, its trailing spaces, and its missing final newline are content
    // (RQ-8, D-10), and this is the line that would destroy them if it did
    // anything at all to them.
    return "---\n" + frontMatter + "---\n" + document.body
  }

  // MARK: - Writing

  /// Writes a document to disk as `CAST.md`.
  ///
  /// ``generate(document:)`` plus an atomic write, and deliberately nothing
  /// else — see this extension's documentation for why no path normalization
  /// happens here.
  ///
  /// This is one of the few places in the library that touches the filesystem,
  /// and it touches exactly `fileURL`. It creates no directories, enumerates
  /// nothing, stats nothing, and resolves no symlink (RQ-7). A destination whose
  /// parent directory does not exist is an error from Foundation, not a
  /// directory this method decides to create.
  ///
  /// The write is atomic: readers see either the previous file or the complete
  /// new one, never a half-written roster. `String.write(to:atomically:
  /// encoding:)` does the temp-file-and-rename itself, which is why there is no
  /// hand-rolled version of it here.
  ///
  /// - Parameters:
  ///   - document: The document to write.
  ///   - fileURL: The destination. By convention `CAST.md`, beside the project's
  ///     `PROJECT.md` — every path the document holds is relative to the
  ///     destination's directory (RQ-6, D-7), so writing it elsewhere silently
  ///     invalidates them. This method does not check that, because checking
  ///     would mean touching the filesystem.
  /// - Throws: Whatever ``generate(document:)`` throws, or Foundation's own
  ///   error if the file cannot be written.
  public func write(document: CastDocument, to fileURL: URL) throws {
    // `.utf8`, stated rather than inferred: the parser reads UTF-8 and the
    // round-trip gate compares bytes, so the encoding is part of the contract.
    try generate(document: document).write(to: fileURL, atomically: true, encoding: .utf8)
  }
}
