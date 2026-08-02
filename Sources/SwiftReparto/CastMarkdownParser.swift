//
//  CastMarkdownParser.swift
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
// (D-1). If a decode needs an option this file cannot reach, add a function
// there rather than an import here.

/// Reads a `CAST.md`: the YAML front matter becomes a ``CastDocument``, and the
/// markdown after it is carried through byte-for-byte (RQ-10).
///
/// ```swift
/// let parser = CastMarkdownParser()
/// let document = try parser.parse(fileURL: url)
/// ```
///
/// ## The body is bytes, not text to be tidied (RQ-8, D-10)
///
/// Everything after the closing `---` is copied out of the input by index and
/// handed back untouched. CRLF stays CRLF, a missing final newline stays
/// missing, trailing spaces stay, and a `---` line *inside* the body is body —
/// the closing delimiter is the first one after the opening one, and every byte
/// past its terminator is content.
///
/// This is why the familiar `split(separator:)` / `joined(separator:)` /
/// `trimmingCharacters(in:)` front-matter idiom is not used here. That idiom
/// rewrites CRLF as LF and eats the trailing newline, and both are byte changes
/// under a requirement that says "byte-for-byte" and a gate that asserts by
/// SHA-256.
///
/// ## Errors are typed, and none of them means "empty"
///
/// Every failure is a ``CastParseError`` (RQ-12). A document declaring
/// `type: cast` with `cast: []` is a *success* carrying an empty roster — see
/// `CastParseError.swift` for why that distinction is load-bearing.
///
/// ## Emission lives in `CastMarkdownGenerator.swift`
///
/// `generate(document:)` and `write(document:to:)` are declared on this type —
/// RQ-10 puts all four entry points on one value — but they are implemented in
/// an extension in `CastMarkdownGenerator.swift`. The split is by direction, not
/// by type: this file is the reader, that one is the writer, and the writer's
/// documentation states the inversion it performs on the body split below.
public struct CastMarkdownParser: Sendable {

  /// Create a parser.
  ///
  /// The type holds no state — it is a namespace with an initializer, which is
  /// what lets it be `Sendable` without qualification. Note in particular that
  /// it stores no YAML coder: `YAMLEncoder` and `YAMLDecoder` are non-`Sendable`
  /// classes, so holding one would forfeit that (RQ-15). ``YAMLCoding``
  /// constructs them per call for the same reason.
  public init() {}

  // MARK: - Parsing

  /// Parses a `CAST.md`'s contents.
  ///
  /// - Important: **This entry point does not normalize paths, and that is
  ///   deliberate (D-7).** Every path a cast document carries is relative to the
  ///   directory holding its `CAST.md`, and a bare `String` has no directory —
  ///   there is nothing to relativize against and this method will not invent
  ///   one. A document parsed from a string therefore carries exactly the path
  ///   strings the string contained, absolute ones included, and normalizing
  ///   them is the caller's job. Callers that have the file's location should
  ///   use ``parse(fileURL:)``, which does normalize.
  ///
  /// - Parameter content: The whole file: a leading `---`, YAML front matter, a
  ///   closing `---`, and then markdown.
  /// - Returns: The parsed document, with ``CastDocument/body`` holding every
  ///   byte after the closing delimiter's line terminator, verbatim.
  /// - Throws: ``CastParseError/noFrontMatter`` when there is no delimited
  ///   block to read; ``CastParseError/invalidYAML(_:)`` when there is one and
  ///   it will not parse; and ``CastParseError/missingTypeCast``,
  ///   ``CastParseError/missingCastKey``,
  ///   ``CastParseError/missingCharacter(index:)``, or
  ///   ``CastParseError/unsupportedSchemaVersion(found:supported:)`` from
  ///   ``CastDocument``'s own decoding.
  public func parse(content: String) throws -> CastDocument {
    // UTF-8 bytes, not `Character`s, and not for speed.
    //
    // Swift's `Character` is a grapheme cluster, and CRLF is ONE grapheme:
    // `"\r\n"` is a single `Character`, so `content.firstIndex(of: "\n")` walks
    // straight past the end of a CRLF line and `line.hasSuffix("\r")` is never
    // true. A line scanner written over the `Character` view silently does the
    // wrong thing on exactly the input RQ-8 cares most about. Bytes have no
    // such ambiguity, and "byte-for-byte" is the requirement's own word.
    let bytes = Array(content.utf8)

    guard let split = splitFrontMatter(bytes) else {
      throw CastParseError.noFrontMatter
    }

    // Valid UTF-8 in, valid UTF-8 out: these slices came from a `String`, so
    // the round trip through `String(decoding:as:)` reproduces the input bytes
    // exactly and substitutes nothing.
    let frontMatter = String(decoding: bytes[split.frontMatter], as: UTF8.self)
    let body = String(decoding: bytes[split.body], as: UTF8.self)

    var document: CastDocument
    do {
      document = try decodeYAML(CastDocument.self, from: frontMatter)
    } catch let error as CastParseError {
      // Rethrown unchanged, and this clause is why there is no blanket `catch`
      // here. `CastDocument.init(from:)` raises four of the six
      // `CastParseError` cases itself, and `decodeYAML` is careful to let them
      // through as themselves; collapsing them into `.invalidYAML` here would
      // undo both and report "not valid YAML" for front matter that parsed
      // perfectly and merely said the wrong thing.
      throw error
    } catch {
      throw CastParseError.invalidYAML(failureMessage(for: error))
    }

    // The decoder cannot see the body and sets it empty; the split owns it.
    document.body = body
    return document
  }

  /// Reads and parses a `CAST.md` from disk, normalizing its paths against the
  /// file's own directory (D-7).
  ///
  /// This is one of only two places in the library that touch the filesystem —
  /// the other is `ProjectCastImporter` — and each reads exactly the one URL it
  /// is handed. Nothing here scans a directory, follows a reference, or checks
  /// whether any path in the document exists (RQ-7).
  ///
  /// Relativization happens **on the way in, never on the way out**: because
  /// this method strips the file's own directory prefix from any absolute path
  /// it finds, a document obtained from a file never holds an absolute path,
  /// and RQ-6's "absolute paths decode but are never emitted" holds by
  /// construction rather than by a check at write time.
  ///
  /// - Parameter fileURL: The `CAST.md` to read. Its directory —
  ///   `fileURL.deletingLastPathComponent()` — is the base every path in the
  ///   document is made relative to.
  /// - Returns: The parsed document.
  /// - Throws: A ``CastParseError`` for anything wrong with the document's
  ///   contents. A file that cannot be read or is not UTF-8 throws Foundation's
  ///   own error instead, unchanged and untranslated: "there is no such file"
  ///   is not a statement about cast documents, and flattening it into one
  ///   would tell the caller the wrong thing.
  public func parse(fileURL: URL) throws -> CastDocument {
    let content = try String(contentsOf: fileURL, encoding: .utf8)
    let document = try parse(content: content)
    return relativizingPaths(in: document, to: fileURL.deletingLastPathComponent())
  }

}

// MARK: - Front-matter split (D-10)
//
// Declared once, at module scope, on purpose — exactly like
// `relativizingPaths(in:to:)` below. `ProjectCastImporter` shares this split
// rather than restating the delimiter rules, so import and parse cannot
// silently disagree about what counts as front matter (Sortie 12a). It is
// `internal`, not `public`: this is a module-internal implementation detail,
// not API surface.

/// A closing `---` was found: the byte ranges of the YAML block and of the
/// body that follows it.
///
/// Ranges rather than strings, so the caller decides what to materialize and
/// neither piece is ever assembled from parts.
struct FrontMatterSplit {
  /// Every byte between the opening delimiter's terminator and the start of
  /// the closing delimiter's line. This is the YAML text, including the
  /// terminator of its own last line.
  let frontMatter: Range<Int>

  /// Every byte after the closing delimiter's line terminator, to end of
  /// file. Empty when the file ends at the delimiter.
  let body: Range<Int>
}

/// Locates the front-matter block, or reports that there isn't one.
///
/// The rules, stated once:
///
/// - The very first line must be a delimiter. Front matter that starts on
///   line 2 is not front matter.
/// - The block ends at the **first** delimiter line after the opening one.
///   Everything past that line's terminator is body, `---` lines included —
///   which is what makes a markdown body containing a horizontal rule or a
///   nested front-matter example survive intact.
/// - No closing delimiter means no front matter, not "front matter running to
///   end of file". A file whose entire content is YAML with a stray leading
///   `---` has no body and no closing marker; treating it as parseable would
///   turn a truncated file into a successful parse.
///
/// - Parameter bytes: The whole file, as UTF-8 bytes.
/// - Returns: The split, or `nil` when the content carries no front matter.
func splitFrontMatter(_ bytes: [UInt8]) -> FrontMatterSplit? {
  let opening = scanLine(bytes, from: 0)

  // No opening delimiter at all, or the file is nothing but `---` with no
  // terminator, in which case there is no room for a closing one.
  guard isDelimiterLine(bytes, opening.contentRange), opening.hasTerminator else {
    return nil
  }

  let frontMatterStart = opening.nextLineStart
  var lineStart = frontMatterStart

  while lineStart < bytes.count {
    let line = scanLine(bytes, from: lineStart)

    if isDelimiterLine(bytes, line.contentRange) {
      // `lineStart` is the first byte of the closing delimiter's line, so the
      // front matter ends just before it — carrying the terminator of its own
      // last line, which is what makes it a well-formed YAML document.
      //
      // `line.nextLineStart` is the first byte after that delimiter's
      // terminator, and it is the body's first byte. It equals `bytes.count`
      // when the file ends at the delimiter, which yields an empty body
      // rather than a special case.
      return FrontMatterSplit(
        frontMatter: frontMatterStart..<lineStart,
        body: line.nextLineStart..<bytes.count)
    }

    guard line.hasTerminator else { break }
    lineStart = line.nextLineStart
  }

  return nil
}

/// One line's geometry, in byte offsets.
struct ScannedLine {
  /// The line's bytes, excluding its terminator — and excluding the `\r` of a
  /// CRLF, which belongs to the terminator and not to the content.
  let contentRange: Range<Int>

  /// The first byte of the next line, or the end of the file.
  let nextLineStart: Int

  /// Whether the line was terminated at all. `false` only for a final line
  /// with no trailing newline.
  let hasTerminator: Bool
}

/// Measures the line beginning at `start`.
///
/// LF and CRLF are the recognized terminators. A lone CR is not: it is
/// classic-Mac OS 9 line ending, it does not appear in any file this library
/// has ever been handed, and treating it as a terminator would split a body
/// that deliberately contains one. It stays in the line's content, where it
/// will be copied through verbatim like every other byte.
///
/// - Parameters:
///   - bytes: The whole file.
///   - start: The line's first byte. Must be a valid offset into `bytes`, or
///     `bytes.count` for the empty line at end of file.
/// - Returns: The line's geometry.
func scanLine(_ bytes: [UInt8], from start: Int) -> ScannedLine {
  let lineFeed = UInt8(ascii: "\n")
  let carriageReturn = UInt8(ascii: "\r")

  var cursor = start
  while cursor < bytes.count, bytes[cursor] != lineFeed {
    cursor += 1
  }

  guard cursor < bytes.count else {
    return ScannedLine(
      contentRange: start..<bytes.count,
      nextLineStart: bytes.count,
      hasTerminator: false)
  }

  // The `\r` of a CRLF is part of the terminator, so the delimiter test below
  // sees `---` on a CRLF file exactly as it does on an LF one.
  let contentEnd = (cursor > start && bytes[cursor - 1] == carriageReturn) ? cursor - 1 : cursor

  return ScannedLine(
    contentRange: start..<contentEnd,
    nextLineStart: cursor + 1,
    hasTerminator: true)
}

/// Whether a line's content is a front-matter delimiter.
///
/// Exactly three hyphens, then nothing but spaces and tabs. Trailing
/// horizontal whitespace is tolerated because `CAST.md` is hand-edited and an
/// invisible trailing space is not a reason to tell someone their file is not
/// a cast document; tolerating it widens what parses and changes no byte of
/// the body, since the body begins after the terminator either way.
///
/// Four hyphens is not a delimiter. `----` is a markdown horizontal rule, and
/// a body is allowed to contain one.
func isDelimiterLine(_ bytes: [UInt8], _ range: Range<Int>) -> Bool {
  let hyphen = UInt8(ascii: "-")
  let space = UInt8(ascii: " ")
  let tab = UInt8(ascii: "\t")

  guard range.count >= 3 else { return false }
  let delimiterEnd = range.lowerBound + 3
  guard bytes[range.lowerBound..<delimiterEnd].allSatisfy({ $0 == hyphen }) else { return false }
  return bytes[delimiterEnd..<range.upperBound].allSatisfy { $0 == space || $0 == tab }
}

// MARK: - Error text

/// The message carried by ``CastParseError/invalidYAML(_:)``.
///
/// `localizedDescription` is deliberately not used. A `DecodingError` renders
/// through it as "The data couldn't be read because it isn't in the correct
/// format.", and a `YamlError` — which is not a `LocalizedError` — as "The
/// operation couldn't be completed.", so both would discard the line and
/// column the caller was promised. The parser's own `debugDescription` and
/// `CustomStringConvertible` text carry that detail, so those are what travel.
///
/// Shared with `ProjectCastImporter` so a `.invalidYAML` message is curated
/// identically on both paths (Sortie 12a task 4).
///
/// - Parameter error: The failure raised beneath the decode.
/// - Returns: A message naming what failed and, where the parser knew, where.
func failureMessage(for error: Error) -> String {
  guard let decodingError = error as? DecodingError else {
    // `YamlError` lands here; its description includes the line, column, and
    // the offending context libyaml reported.
    return String(describing: error)
  }

  let context: DecodingError.Context
  switch decodingError {
  case .dataCorrupted(let errorContext):
    context = errorContext
  case .keyNotFound(_, let errorContext):
    context = errorContext
  case .typeMismatch(_, let errorContext):
    context = errorContext
  case .valueNotFound(_, let errorContext):
    context = errorContext
  @unknown default:
    return String(describing: decodingError)
  }

  // A `dataCorrupted` raised by Yams' own wrapping says only "The given data
  // was not valid YAML."; the real cause is the `underlyingError` beneath it.
  let cause = context.underlyingError.map { " \(String(describing: $0))" } ?? ""
  let path = context.codingPath.map(\.stringValue).joined(separator: ".")
  let location = path.isEmpty ? "" : " (at '\(path)')"
  return context.debugDescription + cause + location
}

// MARK: - Path relativization (D-7, RQ-7)

/// Returns `document` with every absolute path rewritten relative to
/// `directory`, and everything else untouched (D-7).
///
/// **Declared once, at module scope, on purpose.** Both entry points that know
/// where a document came from run this same function — ``CastMarkdownParser``
/// against the `CAST.md`'s directory, and `ProjectCastImporter` against the
/// `PROJECT.md`'s. Those two directories are the same directory in practice,
/// since `CAST.md` is written beside `PROJECT.md`, and one rule applied twice
/// is what keeps them from drifting into a rule plus an exception. Call it; do
/// not copy it, and do not make it a method on either caller.
///
/// ## It is string manipulation, and nothing more (RQ-7)
///
/// It trims a known prefix. It does not stat, does not resolve symlinks, does
/// not canonicalize, does not standardize, and never asks the filesystem
/// whether any of these paths exists — SwiftReparto carries path strings and a
/// consumer that wants to know whether a `.vox` file is really there asks the
/// filesystem itself.
///
/// One consequence is deliberate and is asserted by test: **a path that does
/// not carry the base prefix is left exactly as it is.** No `../` chain is
/// synthesized to reach a location outside the directory. Whether such a
/// relative path would even be meaningful depends on facts only the disk has —
/// which is the mount, what is a symlink — and this library does not ask.
///
/// ## What it rewrites, and what it does not
///
/// Only ``CastMember/voices``, because that is the only declared path field the
/// beta has. `appearance` is deferred (D-3) and rides in
/// ``CastMember/extraKeys`` as opaque preserved data, and this function does not
/// reach into that dictionary: RQ-4 promises undeclared keys re-emit verbatim,
/// and rewriting strings inside them would break that promise for the sake of
/// guessing which ones were paths. When `appearance` becomes a declared field,
/// it is added here — that is part of the cost of declaring it.
///
/// - Parameters:
///   - document: The document to normalize.
///   - directory: The directory the document's paths are relative to. For
///     ``CastMarkdownParser/parse(fileURL:)`` this is the `CAST.md`'s own
///     directory.
/// - Returns: A copy of `document` whose path strings are relative to
///   `directory` wherever they were beneath it.
internal func relativizingPaths(in document: CastDocument, to directory: URL) -> CastDocument {
  let prefix = directoryPathPrefix(for: directory)

  var relativized = document
  for index in relativized.cast.indices {
    var rewritten: [String: [String]] = [:]
    rewritten.reserveCapacity(relativized.cast[index].voices.count)
    for (provider, paths) in relativized.cast[index].voices {
      rewritten[provider] = paths.map { path in
        guard path.hasPrefix(prefix) else { return path }
        return String(path.dropFirst(prefix.count))
      }
    }
    relativized.cast[index].voices = rewritten
  }
  return relativized
}

/// The prefix an absolute path must carry to be considered inside `directory`.
///
/// The trailing separator is added here rather than assumed, because
/// `URL.path(percentEncoded:)` reports `/a/b` for a directory URL whose string
/// form is `/a/b/`, and the separator is what stops `/a/bravo/x.vox` from
/// matching a base of `/a/b`. Existing trailing separators are removed first so
/// exactly one is present regardless of how the URL was spelled — including the
/// filesystem root, whose prefix is a single `/`.
///
/// `path(percentEncoded:)` is a pure accessor on the URL's own components; like
/// everything else on this path it touches no filesystem (RQ-7).
private func directoryPathPrefix(for directory: URL) -> String {
  var prefix = directory.path(percentEncoded: false)
  while prefix.hasSuffix("/") {
    prefix.removeLast()
  }
  return prefix + "/"
}
