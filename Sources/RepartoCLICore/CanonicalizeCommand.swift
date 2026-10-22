//
//  CanonicalizeCommand.swift
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

import ArgumentParser
import Foundation
import SwiftReparto

/// `reparto canonicalize <path> [--apply]` — makes a cast document's character
/// names canonical (RQ-22).
///
/// The explicit step RQ-INV-4 requires: decoding never rewrites `character`,
/// so a document's names become canonical only when someone runs this.
///
/// - **Dry run by default.** Without `--apply` it reads the document and
///   prints each planned rename to standard output, and writes nothing.
/// - **Refuses on a collision**, with or without `--apply`: if two members
///   would share a canonical name, nothing is renamed or written, and it
///   exits with ``RepartoExitCode/nameCollision``.
/// - **`--apply` always writes**, even when no name changes. That is the
///   deliberate normalizing write ("first write is a normalizing write" in
///   `AGENTS.md`): run it once on a live project and commit the result alone.
///
/// A name with no canonical form is left as written and reported on standard
/// error. A thin shell: the library calls are
/// ``SwiftReparto/CastMarkdownParser/parse(fileURL:)``,
/// ``SwiftReparto/CastMember/canonicalName(_:)``, and
/// ``SwiftReparto/CastMarkdownParser/write(document:to:)``.
public struct CanonicalizeCommand: ParsableCommand {

  /// `canonicalize`'s name, abstract, and discussion text.
  public static let configuration = CommandConfiguration(
    commandName: "canonicalize",
    abstract: "Make every character name in a CAST.md canonical.",
    discussion: """
      Canonical names are the screenplay cue in uppercase, with trailing cue \
      extensions such as (V.O.) and a leading @ removed, whitespace \
      collapsed, and Unicode NFC.

      Without --apply this is a dry run: each rename is printed to standard \
      output and nothing is written. With --apply the renames are made and \
      the document is written back — always, even if no name changed, which \
      makes this the deliberate first (normalizing) write of a hand-edited \
      file.

      If two members would end up with the same name, nothing is renamed or \
      written, with or without --apply. A name with no canonical form is \
      left as written and reported on standard error.

      Exit codes:
        \(RepartoExitCode.success)  success
        \(RepartoExitCode.parseError)  the document could not be parsed
        \(RepartoExitCode.ioError)  any other failure
        \(RepartoExitCode.nameCollision)  two members would share a canonical name
      """
  )

  /// The `CAST.md` to canonicalize.
  @Argument(help: "Path to the CAST.md file to canonicalize.")
  var path: String

  /// Makes the renames and writes the document. Without it, nothing is
  /// written.
  @Flag(name: .long, help: "Rename and write the file. Without this, nothing is written.")
  var apply: Bool = false

  /// Where this command's output goes. Defaults to the real streams;
  /// overridable at construction for tests.
  public var sink: any OutputSink = ConsoleOutputSink()

  /// Excludes `sink` from the `Decodable` conformance — see
  /// ``ValidateCommand``'s identical declaration for why.
  private enum CodingKeys: String, CodingKey {
    case path
    case apply
  }

  /// Required by `ParsableCommand`.
  public init() {}

  /// Constructs the command directly, bypassing argument parsing.
  public init(path: String, apply: Bool = false, sink: any OutputSink = ConsoleOutputSink()) {
    self.path = path
    self.apply = apply
    self.sink = sink
  }

  /// Plans the renames, then either reports them or applies and writes them.
  ///
  /// - Throws: An `ExitCode` carrying the mapped exit status.
  public func run() throws {
    let url = URL(fileURLWithPath: path)
    do {
      let parser = CastMarkdownParser()
      let document = try parser.parse(fileURL: url)
      let plan = CanonicalizationPlan(for: document.cast)
      if !plan.collisions.isEmpty {
        throw CanonicalizationError.collision(plan.collisions)
      }

      for warning in plan.failureWarnings {
        sink.writeError(warning + "\n")
      }
      for rename in plan.renames {
        sink.writeOutput("\(rename.from) -> \(rename.to)\n")
      }
      if plan.renames.isEmpty {
        sink.writeOutput("All names are already canonical.\n")
      }

      if apply {
        try parser.write(document: plan.applied(to: document), to: url)
      } else if !plan.renames.isEmpty {
        sink.writeOutput("Dry run: nothing was written. Pass --apply to rename.\n")
      }
    } catch {
      sink.writeError(errorMessage(for: error) + "\n")
      throw ExitCode(repartoExitCode(for: error))
    }
  }
}
