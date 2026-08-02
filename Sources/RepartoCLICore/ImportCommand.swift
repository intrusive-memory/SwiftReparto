//
//  ImportCommand.swift
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

/// `reparto import <project-md-path>` — writes a versioned CAST.md from a
/// `PROJECT.md`'s cast data (D-6).
///
/// A thin shell: the only library calls are
/// ``SwiftReparto/ProjectCastImporter/importCast(fileURL:)``,
/// ``SwiftReparto/CastMarkdownParser/generate(document:)``, and
/// ``SwiftReparto/CastMarkdownParser/write(document:to:)``. Nothing here
/// reads a YAML block, locates a document's delimited header, or builds
/// markdown of its own — and nothing here removes the source `cast:` data
/// from `PROJECT.md` (D-13); import is read-only with respect to its source.
///
/// **This command calls the file-URL entry point on `ProjectCastImporter`,
/// never the one that takes a raw `String` (Sortie 17 directive B).** The
/// string-taking entry point does not relativize paths — that is only
/// correct for a caller with no directory to relativize against, and this
/// command always has one. Reading the file itself and handing the library a
/// `String` would silently write absolute paths into the emitted document: a
/// file that still parses while every
/// voice pointer inside it is wrong, which is exactly the failure task 3b
/// exists to refuse, arriving through a different door.
public struct ImportCommand: ParsableCommand {

  /// `import`'s name, abstract, and discussion text.
  ///
  /// The exit codes named in `discussion` are read from ``RepartoExitCode``,
  /// not restated as literals, so this text and `repartoExitCode(for:)` in
  /// `ExitMapping.swift` cannot drift apart.
  public static let configuration = CommandConfiguration(
    commandName: "import",
    abstract: "Import a cast roster from a PROJECT.md into a versioned CAST.md.",
    discussion: """
      Reads the cast data out of <project-md-path> and writes it as a \
      versioned CAST.md. --output defaults to a file named CAST.md beside \
      the source PROJECT.md — every relative path the imported roster holds \
      is relative to that directory, so the two files must share it for \
      those paths to still resolve.

      Refuses to overwrite an existing --output, and refuses an --output in \
      a directory other than the source's, unless --force is given; either \
      refusal is a guard, not a hard block. --dry-run performs the import \
      but writes nothing: the document that would have been written is \
      printed to standard output instead.

      Exit codes:
        \(RepartoExitCode.success)  success
        \(RepartoExitCode.parseError)  the source could not be imported
        \(RepartoExitCode.outputExists)  the destination exists (pass --force to overwrite)
        \(RepartoExitCode.outputDirectoryMismatch)  --output is outside the source directory (pass --force to override)
        \(RepartoExitCode.ioError)  any other failure
      """
  )

  /// The `PROJECT.md` to import cast data from.
  @Argument(help: ArgumentHelp("Path to the source PROJECT.md.", valueName: "project-md-path"))
  var projectPath: String

  /// The `CAST.md` to write. Defaults to a file named `CAST.md` beside
  /// `projectPath` (D-7).
  @Option(
    name: .long,
    help: "Destination CAST.md path. Defaults to CAST.md beside <project-md-path>.")
  var output: String?

  /// Waives both write guards: an existing destination, and a destination
  /// outside the source's directory.
  @Flag(
    name: .long,
    help: "Overwrite an existing destination, or write outside the source directory.")
  var force: Bool = false

  /// Performs the import but writes nothing; prints the document that would
  /// have been written to standard output instead.
  @Flag(
    name: .long,
    help: "Write nothing; print the CAST.md that would be produced to standard output.")
  var dryRun: Bool = false

  /// Where this command's output goes (Sortie 17 task 6a). Defaults to the
  /// real streams; overridable at construction for tests.
  public var sink: any OutputSink = ConsoleOutputSink()

  /// Excludes `sink` from the `Decodable` conformance `ParsableArguments`
  /// requires — see ``ValidateCommand``'s identical declaration for why.
  private enum CodingKeys: String, CodingKey {
    case projectPath
    case output
    case force
    case dryRun
  }

  /// Required by `ParsableCommand` so ArgumentParser can construct this
  /// command before populating ``projectPath``, ``output``, ``force``, and
  /// ``dryRun`` from the parsed arguments.
  public init() {}

  /// Constructs the command directly, bypassing argument parsing.
  public init(
    projectPath: String,
    output: String? = nil,
    force: Bool = false,
    dryRun: Bool = false,
    sink: any OutputSink = ConsoleOutputSink()
  ) {
    self.projectPath = projectPath
    self.output = output
    self.force = force
    self.dryRun = dryRun
    self.sink = sink
  }

  /// Imports ``projectPath``'s cast data and either writes it to
  /// ``output`` (or the default beside the source) or, under ``dryRun``,
  /// prints it to ``sink`` instead.
  ///
  /// The only library calls are
  /// ``SwiftReparto/ProjectCastImporter/importCast(fileURL:)``,
  /// ``SwiftReparto/CastMarkdownParser/generate(document:)``, and
  /// ``SwiftReparto/CastMarkdownParser/write(document:to:)`` — see this
  /// type's documentation for why the file-URL importer entry point is the
  /// only one this command is allowed to call. Every failure, including both
  /// write guards, is written to ``sink`` and mapped to an exit code by
  /// `repartoExitCode(for:)`, never decided inline here.
  ///
  /// - Throws: An `ExitCode` carrying the mapped exit status. This is
  ///   ArgumentParser's own control-flow convention for reporting a
  ///   non-zero exit, not an error in the ordinary sense.
  public func run() throws {
    let sourceURL = URL(fileURLWithPath: projectPath)
    let destinationURL =
      output.map { URL(fileURLWithPath: $0) }
      ?? sourceURL.deletingLastPathComponent().appendingPathComponent("CAST.md")

    do {
      let document = try ProjectCastImporter().importCast(fileURL: sourceURL)
      let parser = CastMarkdownParser()

      if dryRun {
        sink.writeOutput(try parser.generate(document: document))
        return
      }

      if !force {
        if FileManager.default.fileExists(atPath: destinationURL.path) {
          throw ImportGuardError.outputExists(destinationURL)
        }
        if directoryPath(of: destinationURL) != directoryPath(of: sourceURL) {
          throw ImportGuardError.outputDirectoryMismatch(output: destinationURL, source: sourceURL)
        }
      }

      try parser.write(document: document, to: destinationURL)
    } catch {
      sink.writeError(errorMessage(for: error) + "\n")
      throw ExitCode(repartoExitCode(for: error))
    }
  }
}

/// The directory a file URL lives in, as a comparable string.
///
/// `standardizedFileURL` collapses `.`/`..` components so two spellings of
/// the same directory compare equal; it does not resolve symlinks, which
/// matches this package's stance elsewhere that path work is string work.
private func directoryPath(of fileURL: URL) -> String {
  fileURL.deletingLastPathComponent().standardizedFileURL.path
}
