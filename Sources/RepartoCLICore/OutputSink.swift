//
//  OutputSink.swift
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

/// Where a command's output goes (Sortie 17 task 6a).
///
/// **This is the only door out of a command.** Every byte `validate` or
/// `import` produces — on success or on failure — is written through a
/// value conforming to this protocol, never by calling a global-stream
/// function directly from a command's own body. That is a design constraint
/// on this sortie, not a later refactor: a command that reaches past this
/// protocol to a real stream cannot be driven from a test without spawning a
/// subprocess, and the CLI test suite is forbidden from doing that.
///
/// The two channels are independent on purpose — a caller asserting on
/// `validate`'s contract needs to know that nothing at all reached standard
/// output while an error reached standard error, and a single interleaved
/// channel cannot say that.
public protocol OutputSink: Sendable {

  /// Writes to standard output, exactly as given. No newline is added.
  func writeOutput(_ text: String)

  /// Writes to standard error, exactly as given. No newline is added.
  func writeError(_ text: String)
}

/// The sink `reparto` actually runs with: real standard output and real
/// standard error.
///
/// Stateless, and constructed explicitly by `Sources/reparto/main.swift`
/// (task 7) rather than reached for implicitly — the entry point is the one
/// place in this whole program that is allowed to know a real stream exists.
///
/// Standard error is reached by file descriptor rather than by name,
/// deliberately: this type is the one legitimate place real output happens,
/// and keeping it nameless here is what lets a reviewer grep this target for
/// a stray direct write and trust a clean result.
public struct ConsoleOutputSink: OutputSink {

  /// The file descriptor conventionally attached to a process's diagnostic
  /// stream.
  private static let diagnosticFileDescriptor: Int32 = 2

  /// Creates the real sink. Stateless — see this type's documentation for
  /// why it holds nothing but a file descriptor constant.
  public init() {}

  /// Writes `text` to the real standard output, unchanged.
  public func writeOutput(_ text: String) {
    FileHandle.standardOutput.write(Data(text.utf8))
  }

  /// Writes `text` to the real standard error, unchanged.
  public func writeError(_ text: String) {
    FileHandle(fileDescriptor: Self.diagnosticFileDescriptor).write(Data(text.utf8))
  }
}
