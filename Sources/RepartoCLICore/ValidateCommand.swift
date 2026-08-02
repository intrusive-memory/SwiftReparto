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

/// `reparto validate <path>` — reports whether a document parses (D-6).
///
/// A thin shell: the only library call is
/// ``SwiftReparto/CastMarkdownParser/parse(fileURL:)``. Nothing here reads a
/// YAML block, locates a document's delimited header, or builds markdown of
/// its own.
public struct ValidateCommand: ParsableCommand {

  public static let configuration = CommandConfiguration(
    commandName: "validate",
    abstract: "Validate a CAST.md document.",
    discussion: """
      Parses <path> as a cast document. Exits \(RepartoExitCode.success) if \
      it parses successfully, or \(RepartoExitCode.parseError) if it does \
      not. On failure the parser's own error message is written to standard \
      error, unless --quiet is given; nothing is ever written to standard \
      output.
      """
  )

  /// The `CAST.md` to validate.
  @Argument(help: "Path to the CAST.md file to validate.")
  var path: String

  /// Suppresses the error message on failure; the exit code alone reports
  /// the result.
  @Flag(name: .long, help: "Suppress the error message; rely on the exit code alone.")
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

  public func run() throws {
    do {
      _ = try CastMarkdownParser().parse(fileURL: URL(fileURLWithPath: path))
    } catch {
      if !quiet {
        sink.writeError(errorMessage(for: error) + "\n")
      }
      throw ExitCode(repartoExitCode(for: error))
    }
  }
}
