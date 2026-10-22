//
//  RepartoCommand.swift
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

// Command implementations for the `reparto` executable, kept in a library
// target so they are unit-testable without spawning a subprocess, and so
// that `ArgumentParser` never lands on the `SwiftReparto` library target
// (D-6). This target is deliberately not a product: consumers get the
// `SwiftReparto` library and the `reparto` binary, and nothing here becomes
// public API by accident.
//
// The binary is a shell over the library (D-6). Every subcommand's only
// calls into `SwiftReparto` are `parse`, `generate`, `write`, and
// `ProjectCastImporter` — no command decodes a YAML block, locates a
// document's delimited header, or builds markdown of its own, which is what
// keeps RQ-INV-2's one-writer rule true with a CLI in the picture.

/// The root of the `reparto` CLI (D-6): validate a cast document, or import
/// one out of a `PROJECT.md`.
///
/// ## Exit codes
///
/// Every subcommand routes its failures through the single function
/// `exitCode(for:)` in `ExitMapping.swift`, so the mapping below cannot
/// drift between `validate` and `import`. See that file for the codes
/// themselves — this command's `discussion` renders them from the same
/// constants, so `reparto --help` and the code that computes an exit status
/// can never say two different things.
///
/// ## Output
///
/// No command body here ever calls a global-stream function directly.
/// Every byte a subcommand produces goes through its `sink` property — an
/// `OutputSink`, defaulting to the real streams and overridable at
/// construction (Sortie 17 task 6a). `Sources/reparto/main.swift` is the one
/// place that constructs the real one.
public struct RepartoCommand: ParsableCommand {

  /// `reparto`'s name, abstract, discussion text, and subcommand list.
  ///
  /// **`reparto --help` is the spec.** The exit-code table rendered into
  /// `discussion` reads the same `RepartoExitCode` constants
  /// `ExitMapping.swift`'s `repartoExitCode(for:)` returns, so the two can
  /// never say two different things about what a given failure exits with.
  public static let configuration = CommandConfiguration(
    commandName: "reparto",
    abstract: "Validate, import, and canonicalize CAST.md cast documents.",
    discussion: """
      reparto is a thin shell over the SwiftReparto library: it decodes no \
      YAML, locates no document's delimited header, and builds no markdown \
      of its own. Every write a cast document ever receives happens inside \
      the library, reached either by a program that links SwiftReparto \
      directly or by `reparto import` / `reparto canonicalize --apply` — one \
      writer, several doors.

      Exit codes, mapped in exactly one place so they cannot drift between \
      subcommands:
        \(RepartoExitCode.success)  success
        \(RepartoExitCode.parseError)  the document could not be parsed or imported
        \(RepartoExitCode.outputExists)  'import' destination already exists (pass --force to overwrite)
        \(RepartoExitCode.outputDirectoryMismatch)  'import' --output is outside the source directory (pass --force to override)
        \(RepartoExitCode.ioError)  any other failure (for example, an unreadable file)
        \(RepartoExitCode.nameCollision)  'canonicalize' or 'import' would give two members the same name
      """,
    version: RepartoVersion.current,
    subcommands: [ValidateCommand.self, ImportCommand.self, CanonicalizeCommand.self]
  )

  /// Required by `ParsableCommand` so ArgumentParser can construct the root
  /// command; the root itself carries no parsed arguments of its own — every
  /// argument belongs to one of ``configuration``'s subcommands.
  public init() {}
}
