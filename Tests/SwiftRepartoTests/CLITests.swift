// CLITests.swift
// SwiftRepartoTests
//
// Sortie 18: exercises `RepartoCLICore` directly — never by launching the
// `reparto` binary as a separate process. Every assertion below drives a
// command's own `run()` (or the internal error-to-exit-code mapping it
// relies on) in-process, through the injectable sink Sortie 17 task 6a
// built.
//
// `@testable import RepartoCLICore` reaches two symbols that are internal on
// purpose (see `ExitMapping.swift`): the file-scope `repartoExitCode(for:)`
// function and `ImportGuardError`. Both are named to avoid colliding with
// `ParsableCommand`'s own inherited static members, and nothing in this file
// re-declares a helper under either of those reserved names.
//
// Every command under test here is constructed through its direct
// memberwise initializer, never parsed from a live process's arguments, and
// every file this suite touches lives under a scratch temporary directory —
// nothing is ever written under `Fixtures/`.

import Foundation
import SwiftReparto
import XCTest

@testable import RepartoCLICore

final class CLITests: XCTestCase {

  // MARK: - Capturing sink (Sortie 17 task 6a / Sortie 18 task 2)

  /// Records every write instead of touching a real stream, with the two
  /// channels kept in separate arrays so a test can assert on one without
  /// the other ever being consulted.
  ///
  /// Backed by a lock rather than left unsynchronized: `OutputSink` requires
  /// `Sendable`, and a mutable class needs its own guarantee of that rather
  /// than an unchecked promise resting on "tests happen to run serially."
  final class CapturingSink: OutputSink, @unchecked Sendable {
    private let lock = NSLock()
    private var recordedOutput: [String] = []
    private var recordedError: [String] = []

    var stdout: [String] {
      lock.lock()
      defer { lock.unlock() }
      return recordedOutput
    }

    var stderr: [String] {
      lock.lock()
      defer { lock.unlock() }
      return recordedError
    }

    func writeOutput(_ text: String) {
      lock.lock()
      defer { lock.unlock() }
      recordedOutput.append(text)
    }

    func writeError(_ text: String) {
      lock.lock()
      defer { lock.unlock() }
      recordedError.append(text)
    }
  }

  // MARK: - Scratch files (never under Fixtures/, per this sortie's boundaries)

  private func makeScratchDirectory() throws -> URL {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
      .appendingPathComponent("SwiftRepartoCLITests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    addTeardownBlock {
      try? FileManager.default.removeItem(at: directory)
    }
    return directory
  }

  @discardableResult
  private func writeScratchFile(named name: String, contents: String, in directory: URL) throws
    -> URL
  {
    let url = directory.appendingPathComponent(name)
    try contents.write(to: url, atomically: true, encoding: .utf8)
    return url
  }

  // MARK: - Task 1: argument parsing, ValidateCommand

  func testValidateCommandParsesPathAndQuietFlag() throws {
    let command = try ValidateCommand.parse(["some/CAST.md", "--quiet"])
    XCTAssertEqual(command.path, "some/CAST.md")
    XCTAssertTrue(command.quiet)
  }

  func testValidateCommandDefaultsQuietToFalse() throws {
    let command = try ValidateCommand.parse(["some/CAST.md"])
    XCTAssertEqual(command.path, "some/CAST.md")
    XCTAssertFalse(command.quiet)
  }

  // MARK: - Task 1: argument parsing, ImportCommand

  func testImportCommandParsesAllOptions() throws {
    let command = try ImportCommand.parse([
      "some/PROJECT.md", "--output", "some/other/CAST.md", "--force", "--dry-run",
    ])
    XCTAssertEqual(command.projectPath, "some/PROJECT.md")
    XCTAssertEqual(command.output, "some/other/CAST.md")
    XCTAssertTrue(command.force)
    XCTAssertTrue(command.dryRun)
  }

  /// The "missing `--output`" case from task 1: parsing without it leaves
  /// `output` `nil`, which is what `ImportCommand.run()` reads as "use the
  /// default path beside the source" (D-7).
  func testImportCommandDefaultsOutputForceAndDryRun() throws {
    let command = try ImportCommand.parse(["some/PROJECT.md"])
    XCTAssertEqual(command.projectPath, "some/PROJECT.md")
    XCTAssertNil(command.output)
    XCTAssertFalse(command.force)
    XCTAssertFalse(command.dryRun)
  }

  // MARK: - Task 1/2: error -> exit-code mapping, every CastParseError case

  /// All six `CastParseError` cases named by RQ-12, each asserted against
  /// the single mapping function every subcommand routes through
  /// (`ExitMapping.swift`). Constructed directly rather than parsed from a
  /// fixture: `RejectionFixtureTests.swift` already proves the parser
  /// produces each case from the right input, and duplicating that here
  /// would test the parser a second time instead of the mapping.
  func testExitCodeMappingCoversEveryCastParseErrorCase() {
    let cases: [CastParseError] = [
      .noFrontMatter,
      .invalidYAML("unexpected token"),
      .missingTypeCast,
      .missingCastKey,
      .missingCharacter(index: 0),
      .unsupportedSchemaVersion(found: 2, supported: CastSchemaVersion.current),
    ]

    XCTAssertEqual(cases.count, 6, "expected all six CastParseError cases to be exercised")

    for error in cases {
      XCTAssertEqual(
        repartoExitCode(for: error),
        RepartoExitCode.parseError,
        "\(error) did not map to RepartoExitCode.parseError")
    }
  }

  func testExitCodeMappingForImportGuardErrors() {
    let output = URL(fileURLWithPath: "/tmp/scratch/CAST.md")
    let source = URL(fileURLWithPath: "/tmp/other/PROJECT.md")

    XCTAssertEqual(
      repartoExitCode(for: ImportGuardError.outputExists(output)),
      RepartoExitCode.outputExists)
    XCTAssertEqual(
      repartoExitCode(
        for: ImportGuardError.outputDirectoryMismatch(output: output, source: source)),
      RepartoExitCode.outputDirectoryMismatch)
  }

  func testExitCodeMappingDefaultsToIOErrorForAnUnrecognizedError() {
    struct SomeOtherFailure: Error {}
    XCTAssertEqual(repartoExitCode(for: SomeOtherFailure()), RepartoExitCode.ioError)
  }

  // MARK: - ValidateCommand.run(), driven through the sink

  func testValidateSucceedsWritesNothingToEitherChannel() throws {
    let directory = try makeScratchDirectory()
    let castURL = try writeScratchFile(
      named: "CAST.md", contents: try TestFixture.confessionsCastMD.contents(), in: directory)

    let sink = CapturingSink()
    let command = ValidateCommand(path: castURL.path, sink: sink)
    try command.run()

    XCTAssertEqual(sink.stdout, [])
    XCTAssertEqual(sink.stderr, [])
  }

  func testValidateFailureWritesOnlyToStderrWithTheParserMessage() throws {
    let directory = try makeScratchDirectory()
    let badURL = try writeScratchFile(
      named: "reject.md", contents: try TestFixture.rejectNoFrontMatter.contents(), in: directory)

    let sink = CapturingSink()
    let command = ValidateCommand(path: badURL.path, sink: sink)

    XCTAssertThrowsError(try command.run())

    XCTAssertEqual(sink.stdout, [], "a failed validate must never write to standard output")
    XCTAssertEqual(sink.stderr, [errorMessage(for: CastParseError.noFrontMatter) + "\n"])
  }

  func testValidateQuietSuppressesTheMessageOnBothChannels() throws {
    let directory = try makeScratchDirectory()
    let badURL = try writeScratchFile(
      named: "reject.md", contents: try TestFixture.rejectNoFrontMatter.contents(), in: directory)

    let sink = CapturingSink()
    let command = ValidateCommand(path: badURL.path, quiet: true, sink: sink)

    XCTAssertThrowsError(try command.run())

    XCTAssertEqual(sink.stdout, [])
    XCTAssertEqual(sink.stderr, [], "--quiet must suppress the message on both channels")
  }

  // MARK: - ImportCommand.run(): default --output (the missing-flag case)

  func testImportWithoutOutputWritesCastMdBesideTheSourceAndTouchesNoStream() throws {
    let directory = try makeScratchDirectory()
    let projectURL = try writeScratchFile(
      named: "PROJECT.md", contents: try TestFixture.confessionsProjectMD.contents(),
      in: directory)
    let expectedOutputURL = directory.appendingPathComponent("CAST.md")

    let sink = CapturingSink()
    let command = ImportCommand(projectPath: projectURL.path, sink: sink)
    try command.run()

    XCTAssertTrue(FileManager.default.fileExists(atPath: expectedOutputURL.path))
    XCTAssertEqual(sink.stdout, [])
    XCTAssertEqual(sink.stderr, [])
  }

  // MARK: - ImportCommand.run(): --force refusal (tasks 3a/3b)

  func testImportRefusesToOverwriteAnExistingOutputWithoutForce() throws {
    let directory = try makeScratchDirectory()
    let projectURL = try writeScratchFile(
      named: "PROJECT.md", contents: try TestFixture.confessionsProjectMD.contents(),
      in: directory)
    let outputURL = try writeScratchFile(
      named: "CAST.md", contents: "pre-existing, hand-maintained content\n", in: directory)
    let before = try String(contentsOf: outputURL, encoding: .utf8)

    let sink = CapturingSink()
    let command = ImportCommand(projectPath: projectURL.path, output: outputURL.path, sink: sink)

    XCTAssertThrowsError(try command.run())

    let after = try String(contentsOf: outputURL, encoding: .utf8)
    XCTAssertEqual(before, after, "a refused import must not modify the existing destination")
    XCTAssertEqual(sink.stdout, [])
    XCTAssertEqual(
      sink.stderr,
      [errorMessage(for: ImportGuardError.outputExists(outputURL)) + "\n"])
  }

  func testImportForceOverwritesAnExistingOutput() throws {
    let directory = try makeScratchDirectory()
    let projectURL = try writeScratchFile(
      named: "PROJECT.md", contents: try TestFixture.confessionsProjectMD.contents(),
      in: directory)
    let outputURL = try writeScratchFile(
      named: "CAST.md", contents: "pre-existing, hand-maintained content\n", in: directory)

    let sink = CapturingSink()
    let command = ImportCommand(
      projectPath: projectURL.path, output: outputURL.path, force: true, sink: sink)
    try command.run()

    let after = try String(contentsOf: outputURL, encoding: .utf8)
    XCTAssertNotEqual(after, "pre-existing, hand-maintained content\n")
    XCTAssertEqual(sink.stdout, [])
    XCTAssertEqual(sink.stderr, [])
  }

  func testImportRefusesAnOutputDirectoryDifferentFromTheSourceWithoutForce() throws {
    let sourceDirectory = try makeScratchDirectory()
    let elsewhereDirectory = try makeScratchDirectory()
    let projectURL = try writeScratchFile(
      named: "PROJECT.md", contents: try TestFixture.confessionsProjectMD.contents(),
      in: sourceDirectory)
    let outputURL = elsewhereDirectory.appendingPathComponent("CAST.md")

    let sink = CapturingSink()
    let command = ImportCommand(projectPath: projectURL.path, output: outputURL.path, sink: sink)

    XCTAssertThrowsError(try command.run())

    XCTAssertFalse(FileManager.default.fileExists(atPath: outputURL.path))
    XCTAssertEqual(sink.stdout, [])
    let expectedGuardError = ImportGuardError.outputDirectoryMismatch(
      output: outputURL, source: projectURL)
    XCTAssertEqual(sink.stderr, [errorMessage(for: expectedGuardError) + "\n"])
  }

  func testImportForceWritesToADifferentDirectoryThanTheSource() throws {
    let sourceDirectory = try makeScratchDirectory()
    let elsewhereDirectory = try makeScratchDirectory()
    let projectURL = try writeScratchFile(
      named: "PROJECT.md", contents: try TestFixture.confessionsProjectMD.contents(),
      in: sourceDirectory)
    let outputURL = elsewhereDirectory.appendingPathComponent("CAST.md")

    let sink = CapturingSink()
    let command = ImportCommand(
      projectPath: projectURL.path, output: outputURL.path, force: true, sink: sink)
    try command.run()

    XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
    XCTAssertEqual(sink.stdout, [])
    XCTAssertEqual(sink.stderr, [])
  }

  // MARK: - ImportCommand.run(): --dry-run (task 4)

  func testImportDryRunWritesNothingAndPrintsTheDocumentToStdout() throws {
    let directory = try makeScratchDirectory()
    let projectURL = try writeScratchFile(
      named: "PROJECT.md", contents: try TestFixture.confessionsProjectMD.contents(),
      in: directory)
    let outputURL = directory.appendingPathComponent("CAST.md")

    let sink = CapturingSink()
    let command = ImportCommand(projectPath: projectURL.path, dryRun: true, sink: sink)
    try command.run()

    XCTAssertFalse(
      FileManager.default.fileExists(atPath: outputURL.path),
      "--dry-run must not create the destination file")
    XCTAssertEqual(sink.stderr, [])
    XCTAssertEqual(sink.stdout.count, 1)
    let printed = sink.stdout[0]
    XCTAssertTrue(printed.contains("type: cast"))
    XCTAssertTrue(printed.contains("schemaVersion"))

    // The printed document is exactly what `parse` accepts, proving --dry-run
    // is the reviewable form of what would have been written, not a summary
    // of it.
    XCTAssertNoThrow(try CastMarkdownParser().parse(content: printed))
  }

  func testImportDryRunIgnoresAnExistingOutputEntirely() throws {
    // --dry-run never reaches the write guards at all: it returns before
    // either existence or directory check runs (ImportCommand.run()), so an
    // existing destination that would otherwise be refused is simply beside
    // the point.
    let directory = try makeScratchDirectory()
    let projectURL = try writeScratchFile(
      named: "PROJECT.md", contents: try TestFixture.confessionsProjectMD.contents(),
      in: directory)
    let outputURL = try writeScratchFile(
      named: "CAST.md", contents: "pre-existing, hand-maintained content\n", in: directory)
    let before = try String(contentsOf: outputURL, encoding: .utf8)

    let sink = CapturingSink()
    let command = ImportCommand(
      projectPath: projectURL.path, output: outputURL.path, dryRun: true, sink: sink)
    try command.run()

    let after = try String(contentsOf: outputURL, encoding: .utf8)
    XCTAssertEqual(before, after)
    XCTAssertEqual(sink.stdout.count, 1)
    XCTAssertEqual(sink.stderr, [])
  }

  // MARK: - ImportCommand.run(): source-side parse failure

  func testImportOfAnUnimportableSourceWritesOnlyToStderr() throws {
    let directory = try makeScratchDirectory()
    let badURL = try writeScratchFile(
      named: "PROJECT.md", contents: try TestFixture.rejectNoFrontMatter.contents(),
      in: directory)
    let outputURL = directory.appendingPathComponent("CAST.md")

    let sink = CapturingSink()
    let command = ImportCommand(projectPath: badURL.path, sink: sink)

    XCTAssertThrowsError(try command.run())

    XCTAssertFalse(FileManager.default.fileExists(atPath: outputURL.path))
    XCTAssertEqual(sink.stdout, [])
    XCTAssertFalse(sink.stderr.isEmpty)
  }
}
