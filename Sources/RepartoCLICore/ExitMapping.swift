//
//  ExitMapping.swift
//  RepartoCLICore
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
import SwiftReparto

/// Every exit code this build of `reparto` can produce (Sortie 17 task 6).
///
/// Declared once so the codes documented in ``RepartoCommand``'s help text
/// and the codes ``exitCode(for:)`` actually returns are the same
/// integers, read from the same place.
public enum RepartoExitCode {

  /// The command completed successfully.
  public static let success: Int32 = 0

  /// A document could not be read as a cast document — any `CastParseError`
  /// case, on either subcommand's path.
  public static let parseError: Int32 = 1

  /// `import`'s destination already exists and `--force` was not given.
  public static let outputExists: Int32 = 2

  /// `import`'s `--output` names a directory other than the source
  /// `PROJECT.md`'s, and `--force` was not given.
  public static let outputDirectoryMismatch: Int32 = 3

  /// Any other failure — for example, a file that cannot be read at all.
  public static let ioError: Int32 = 4

  /// `canonicalize` or `import` refused because two members would share a
  /// canonical name (RQ-22).
  public static let nameCollision: Int32 = 5
}

/// The two ways `import` refuses to write without `--force` (tasks 3a, 3b).
///
/// Distinct from ``SwiftReparto/CastParseError`` on purpose: both of these
/// documents parse just fine. What is being refused is *where* the write
/// would land, not what the write would contain.
enum ImportGuardError: Error, LocalizedError, Equatable {

  /// The destination already holds a file. Cast data is hand-maintained, and
  /// a silent clobber of it is the exact class of loss this package exists
  /// to prevent (task 3a).
  case outputExists(URL)

  /// The destination's directory differs from the source `PROJECT.md`'s
  /// (task 3b). Every path a cast document holds is relative to its own
  /// directory; writing the document anywhere else leaves it parseable while
  /// every voice pointer inside it silently points at the wrong place.
  case outputDirectoryMismatch(output: URL, source: URL)

  var errorDescription: String? {
    switch self {
    case .outputExists(let url):
      return
        "Refusing to overwrite the existing file at \(url.path). "
        + "Pass --force to overwrite it."

    case .outputDirectoryMismatch(let output, let source):
      return
        "Refusing to write \(output.path): its directory is not the source "
        + "directory (\(source.path)). Every path a cast document holds is "
        + "relative to its own directory, so writing it elsewhere would "
        + "silently invalidate every relative path in the imported roster. "
        + "Pass --force to write there anyway."
    }
  }
}

/// The single place a thrown error becomes a process exit code (task 6).
///
/// Both `validate` and `import` route every failure through this one
/// function rather than deciding their own exit code inline, so the mapping
/// cannot drift between them. Add a case here, in exactly this function,
/// when a command gains a new typed failure — never re-derive the mapping at
/// a call site.
///
/// Named distinctly from `ExitCode` and from `ParsableCommand`'s own
/// inherited `exitCode(for:)`/`message(for:)` static members (ArgumentParser
/// uses those internally to format its own usage and validation errors): an
/// unqualified call from inside a command body would otherwise resolve to
/// the protocol's member ahead of this file-scope function, silently
/// bypassing the mapping this function exists to centralize.
///
/// - Parameter error: The error a subcommand's body caught.
/// - Returns: The exit code that reports it, one of ``RepartoExitCode``'s
///   constants.
func repartoExitCode(for error: Error) -> Int32 {
  switch error {
  case is CastParseError:
    return RepartoExitCode.parseError

  case is CanonicalizationError:
    return RepartoExitCode.nameCollision

  case let guardError as ImportGuardError:
    switch guardError {
    case .outputExists:
      return RepartoExitCode.outputExists
    case .outputDirectoryMismatch:
      return RepartoExitCode.outputDirectoryMismatch
    }

  default:
    return RepartoExitCode.ioError
  }
}

/// A display string for an error, preferring its curated description.
///
/// ``SwiftReparto/CastParseError`` and `ImportGuardError` both conform to
/// `LocalizedError` and supply a distinct `errorDescription` for every case;
/// anything else — a file that cannot be read, for instance — falls back to
/// its own textual description rather than Foundation's generic localized
/// text, which would discard detail a caller was promised.
///
/// - Parameter error: The error to describe.
/// - Returns: The text a command writes through its ``OutputSink``.
func errorMessage(for error: Error) -> String {
  if let described = (error as? LocalizedError)?.errorDescription {
    return described
  }
  return String(describing: error)
}
