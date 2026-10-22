//
//  ValidateCommand.swift
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

import ArgumentParser
import Foundation
import SwiftReparto

/// `reparto validate <path>` — reports whether a document parses (D-6), and
/// warns about what parses but should change.
///
/// A thin shell: the only library calls are
/// ``SwiftReparto/CastMarkdownParser/parse(fileURL:)`` and
/// ``SwiftReparto/CastMember/canonicalName(_:)``. Nothing here reads a YAML
/// block, locates a document's delimited header, or builds markdown of its
/// own.
///
/// Warnings never change the exit code. There are two (0.2.0):
///
/// - A member whose `character` is not canonical (RQ-22, RQ-Q4: a warning,
///   not an error, while live projects still carry mixed case).
/// - A member carrying a legacy `appearance:` block (RQ-25).
///
/// `manifest` is opaque, so there is no path-shape finding (RQ-21 withdrawn).
public struct ValidateCommand: ParsableCommand {

  /// `validate`'s name, abstract, and discussion text.
  ///
  /// The exit codes named in `discussion` are read from ``RepartoExitCode``,
  /// not restated as literals, so this text and `repartoExitCode(for:)` in
  /// `ExitMapping.swift` cannot drift apart.
  public static let configuration = CommandConfiguration(
    commandName: "validate",
    abstract: "Validate a CAST.md document.",
    discussion: """
      Parses <path> as a cast document. Exits \(RepartoExitCode.success) if \
      it parses successfully, or \(RepartoExitCode.parseError) if it does \
      not. On failure the parser's own error message is written to standard \
      error, unless --quiet is given; nothing is ever written to standard \
      output.

      A document that parses may still draw warnings on standard error: a \
      character name that is not canonical (run `reparto canonicalize`), and \
      a deprecated appearance: block. Warnings never change the exit code, \
      and --quiet suppresses them too.
      """
  )

  /// The `CAST.md` to validate.
  @Argument(help: "Path to the CAST.md file to validate.")
  var path: String

  /// Suppresses the error message on failure, and every warning; the exit
  /// code alone reports the result.
  @Flag(name: .long, help: "Suppress errors and warnings; rely on the exit code alone.")
  var quiet: Bool = false

  /// Where this command's output goes (Sortie 17 task 6a). Defaults to the
  /// real streams; overridable at construction for tests, which is the only
  /// override any caller needs — nothing here ever reaches past this value
  /// to a global stream.
  public var sink: any OutputSink = ConsoleOutputSink()

  /// Excludes `sink` from the `Decodable` conformance `ParsableArguments`
  /// requires. `OutputSink` is an existential and cannot conform to
  /// `Decodable`, and it must not: the sink is wired up by whoever
  /// constructs this command, never parsed out of the command line. Listing
  /// only the parsed properties here is what lets `sink` keep its default
  /// value instead.
  private enum CodingKeys: String, CodingKey {
    case path
    case quiet
  }

  /// Required by `ParsableCommand` so ArgumentParser can construct this
  /// command before populating ``path`` and ``quiet`` from the parsed
  /// arguments.
  public init() {}

  /// Constructs the command directly, bypassing argument parsing.
  ///
  /// This is the door a test uses: every parameter has the same default an
  /// end user gets from the command line, and `sink` is the one a test
  /// replaces to capture output without spawning a process.
  public init(path: String, quiet: Bool = false, sink: any OutputSink = ConsoleOutputSink()) {
    self.path = path
    self.quiet = quiet
    self.sink = sink
  }

  /// Parses ``path`` and reports the result through ``sink`` and the process
  /// exit code — nothing more.
  ///
  /// The only library call is
  /// ``SwiftReparto/CastMarkdownParser/parse(fileURL:)``; a thrown
  /// ``SwiftReparto/CastParseError`` is written to ``sink`` (unless
  /// ``quiet`` is set) and mapped to an exit code by `repartoExitCode(for:)`
  /// — never decided inline here.
  ///
  /// - Throws: An `ExitCode` carrying the mapped exit status. This is
  ///   ArgumentParser's own control-flow convention for reporting a
  ///   non-zero exit, not an error in the ordinary sense.
  public func run() throws {
    do {
      let document = try CastMarkdownParser().parse(fileURL: URL(fileURLWithPath: path))
      if !quiet {
        for warning in validationWarnings(for: document) {
          sink.writeError(warning + "\n")
        }
      }
    } catch {
      if !quiet {
        sink.writeError(errorMessage(for: error) + "\n")
      }
      throw ExitCode(repartoExitCode(for: error))
    }
  }
}

/// The deprecation warning for a legacy `appearance:` block (RQ-25), worded
/// as the requirement words it.
let appearanceDeprecationMessage =
  "appearance is deprecated; visual assets belong in the character manifest (`manifest:`)."

/// Every warning `validate` reports for a document that parsed, in roster
/// order.
///
/// - Parameter document: A successfully parsed document.
/// - Returns: One line per finding, without a trailing newline.
func validationWarnings(for document: CastDocument) -> [String] {
  var warnings: [String] = []
  for (index, member) in document.cast.enumerated() {
    let label = "warning: cast member \(index) ('\(member.character)')"
    do throws(CharacterNameError) {
      let canonical = try CastMember.canonicalName(member.character)
      if canonical != member.character {
        warnings.append(
          "\(label): name is not canonical; the canonical form is '\(canonical)'. "
            + "Run `reparto canonicalize` to see every rename.")
      }
    } catch {
      warnings.append(
        "\(label): name has no canonical form: \(error.errorDescription ?? "\(error)")")
    }
    if member[extra: "appearance"] != nil {
      warnings.append("\(label): \(appearanceDeprecationMessage)")
    }
  }
  return warnings
}
