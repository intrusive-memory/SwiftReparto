//
//  CastParseError.swift
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
//  ---
//
//  THE RQ-12 CONTRACT, STATED ONCE, HERE
//
//  Every way a cast document can fail to load is one of the cases below, and
//  the cases exist so a caller can tell two situations apart that a lesser
//  design conflates:
//
//      "this is not a cast document"   vs   "this cast document is empty"
//
//  A file with no front matter, front matter that is not YAML, front matter
//  missing `type: cast`, front matter missing `cast:`, or a member with no
//  `character` — each throws its own case. A document that says `type: cast`
//  and `cast: []` throws NOTHING: it parses to a `CastDocument` whose `cast`
//  is empty, because an empty roster is a fact about the document, not a
//  failure to read it. A caller deciding whether to prompt "add your first
//  character" or "this file isn't a cast list" needs both answers, and only a
//  typed vocabulary can give them.
//
//  Two prohibitions follow from that, and they bind every file in this target,
//  not only this one:
//
//    1. NO UNCONDITIONAL TRAP. Not on an impossible branch, not on a "can't
//       happen" decode, not behind a comment explaining why it can't happen.
//       A library that traps takes its host process down over someone else's
//       malformed file. The exit criteria grep `Sources/` for the standard
//       library's trap function by name, so it does not appear here either —
//       not even in a comment forbidding it.
//
//    2. NO SILENT EMPTY-CAST FALLBACK. Nothing may `try?` a parse and hand
//       back an empty roster. That failure mode is invisible at the call site
//       and lethal one step later: the caller writes the document back out and
//       every character the file contained is gone. That is RQ-INV-2's exact
//       failure with the evidence deleted.
//

import Foundation

/// Every way loading a cast document can fail (RQ-12).
///
/// The type is `Equatable` on purpose: tests — and callers with recovery logic
/// — assert on the *case and its payload*, not on the fact that something
/// threw. `XCTAssertThrowsError(...) { XCTAssertEqual($0 as? CastParseError,
/// .unsupportedSchemaVersion(found: 2, supported: 1)) }` says what went wrong;
/// a bare `throws: Error.self` assertion passes just as happily when the
/// parser throws the wrong error for the wrong reason.
///
/// See this file's header for the contract these cases implement, including
/// why an empty `cast:` is not represented here.
public enum CastParseError: Error, LocalizedError, Equatable {

  /// The content carried no YAML front matter at all.
  ///
  /// This is the "not a cast document" answer: there is no leading `---`
  /// delimited block to read, so nothing about the file claims to be a cast
  /// list.
  case noFrontMatter

  /// Front matter was present but could not be parsed as YAML.
  ///
  /// The associated value is the underlying parser's message, carried verbatim
  /// so a caller can surface line and column information it did not have to
  /// reconstruct.
  ///
  /// - Parameter message: The YAML parser's own description of the failure.
  case invalidYAML(String)

  /// The front matter did not declare `type: cast`.
  ///
  /// RQ-1 requires the declaration. A `PROJECT.md` whose front matter happens
  /// to contain a `cast:` key is not a cast document, and this case is what
  /// keeps SwiftReparto from rewriting one as though it were.
  case missingTypeCast

  /// The front matter declared `type: cast` but carried no `cast:` key.
  ///
  /// Distinct from an empty roster: `cast: []` is a valid document with no
  /// members, while the absence of the key means the document never described
  /// a roster at all.
  case missingCastKey

  /// A member of the `cast:` array had no `character` field.
  ///
  /// - Parameter index: The member's zero-based position in the `cast:` array,
  ///   so a caller can point at the offending entry rather than reporting that
  ///   *something* in the file is wrong.
  case missingCharacter(index: Int)

  /// The document declared a schema version newer than this build supports
  /// (D-12).
  ///
  /// Refusal is deliberate and is the conservative half of D-5. Parsing a
  /// newer document best-effort would let an older writer rewrite it and drop
  /// every field it did not understand. A caller that genuinely wants
  /// best-effort behavior can catch this case and act on the numbers it
  /// carries.
  ///
  /// - Parameters:
  ///   - found: The version the document declared.
  ///   - supported: The newest version this build reads, i.e.
  ///     ``CastSchemaVersion/current``.
  case unsupportedSchemaVersion(found: Int, supported: Int)

  /// A human-readable description of the failure, distinct for every case.
  ///
  /// Distinctness is asserted by test. Two cases sharing a message would make
  /// a log line ambiguous exactly where RQ-12 requires it not to be.
  public var errorDescription: String? {
    switch self {
    case .noFrontMatter:
      return "No YAML front matter found. A cast document must begin with a '---' delimited block."

    case .invalidYAML(let message):
      return "The front matter is not valid YAML: \(message)"

    case .missingTypeCast:
      return "The front matter does not declare 'type: cast', so this is not a cast document."

    case .missingCastKey:
      return
        "The front matter declares 'type: cast' but has no 'cast:' key. "
        + "An empty roster is written as 'cast: []'."

    case .missingCharacter(let index):
      return "The cast member at index \(index) has no 'character' field, which is required."

    case .unsupportedSchemaVersion(let found, let supported):
      return
        "This document declares schema version \(found), but this build of SwiftReparto "
        + "supports version \(supported) at most. Refusing to parse it rather than risk "
        + "rewriting it lossily."
    }
  }
}
