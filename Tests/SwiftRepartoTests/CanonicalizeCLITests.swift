// CanonicalizeCLITests.swift
// SwiftRepartoTests
//
// 0.2.0 CLI behaviour: `reparto validate` warnings (RQ-22 non-canonical
// names, RQ-25 appearance deprecation, no manifest path-shape finding),
// `reparto canonicalize [--apply]` (acceptance 9), and `reparto import`
// canonicalizing names. In-process, through the capturing sink, on scratch
// files only. Synthetic data only.

import Foundation
import SwiftReparto
import XCTest

@testable import RepartoCLICore

final class CanonicalizeCLITests: XCTestCase {

  private typealias CapturingSink = CLITests.CapturingSink

  private func makeScratchDirectory() throws -> URL {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
      .appendingPathComponent(
        "SwiftRepartoCanonicalizeTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
    return directory
  }

  private func write(_ contents: String, named name: String = "CAST.md", in directory: URL)
    throws -> URL
  {
    let url = directory.appendingPathComponent(name)
    try contents.write(to: url, atomically: true, encoding: .utf8)
    return url
  }

  private func castDocument(_ members: [String]) -> String {
    "---\ntype: cast\ncast:\n" + members.joined() + "---\n# Body stays.\n"
  }

  /// The exit status a command's `run()` threw, or `nil` if it returned.
  ///
  /// ArgumentParser's `ExitCode` is read through its `rawValue` by
  /// reflection, so this target needs no `import ArgumentParser` (it does
  /// not declare that dependency).
  private func exitCode(of body: () throws -> Void) -> Int32? {
    do {
      try body()
      return nil
    } catch {
      let rawValue = Mirror(reflecting: error).children.first { $0.label == "rawValue" }?.value
      return (rawValue as? Int32) ?? -1
    }
  }

  // MARK: - validate

  func testValidateWarnsOnNonCanonicalNamesAndExitsZero() throws {
    let directory = try makeScratchDirectory()
    let url = try write(
      castDocument([
        "- character: NARRATOR\n",
        "- character: Narrator (V.O.)\n",
        "- character: AC/DC\n",
      ]), in: directory)

    let sink = CapturingSink()
    try ValidateCommand(path: url.path, sink: sink).run()

    XCTAssertEqual(sink.stdout, [])
    XCTAssertEqual(sink.stderr.count, 2, "\(sink.stderr)")
    XCTAssertTrue(sink.stderr[0].contains("cast member 1"))
    XCTAssertTrue(sink.stderr[0].contains("'NARRATOR'"))
    XCTAssertTrue(sink.stderr[1].contains("cast member 2"))
    XCTAssertTrue(sink.stderr[1].contains("no canonical form"))
  }

  /// Acceptance 8: an `appearance:` block round-trips unchanged (asserted
  /// elsewhere on the fixture) and `validate` emits the deprecation warning.
  func testValidateWarnsOnAppearanceAndExitsZero() throws {
    let directory = try makeScratchDirectory()
    let url = try write(try TestFixture.allFieldsCastMD.contents(), in: directory)

    let sink = CapturingSink()
    try ValidateCommand(path: url.path, sink: sink).run()

    XCTAssertEqual(sink.stdout, [])
    XCTAssertEqual(
      sink.stderr,
      ["warning: cast member 0 ('THE ORACLE'): \(appearanceDeprecationMessage)\n"])
    XCTAssertTrue(
      appearanceDeprecationMessage.hasPrefix(
        "appearance is deprecated; visual assets belong in the character manifest"))
  }

  func testValidateQuietSuppressesWarnings() throws {
    let directory = try makeScratchDirectory()
    let url = try write(try TestFixture.allFieldsCastMD.contents(), in: directory)

    let sink = CapturingSink()
    try ValidateCommand(path: url.path, quiet: true, sink: sink).run()
    XCTAssertEqual(sink.stderr, [])
    XCTAssertEqual(sink.stdout, [])
  }

  /// Acceptance 4 (RQ-21 withdrawn): manifest is opaque, so even a path that
  /// does not look like a dossier draws no finding.
  func testValidateReportsNoManifestPathShapeFinding() throws {
    let directory = try makeScratchDirectory()
    let url = try write(
      castDocument([
        "- character: NARRATOR\n  manifest: somewhere/else/WRONG-NAME.txt\n",
        "- character: COURIER\n  manifest: /absolute/elsewhere/manifest.json\n",
      ]), in: directory)

    let sink = CapturingSink()
    try ValidateCommand(path: url.path, sink: sink).run()
    XCTAssertEqual(sink.stderr, [])
    XCTAssertEqual(sink.stdout, [])
  }

  func testValidateOfTheRoleManifestFixtureIsSilent() throws {
    let directory = try makeScratchDirectory()
    let url = try write(try TestFixture.roleManifestCastMD.contents(), in: directory)

    let sink = CapturingSink()
    try ValidateCommand(path: url.path, sink: sink).run()
    XCTAssertEqual(sink.stderr, [])
  }

  func testValidateInvalidRoleExitsWithParseError() throws {
    let directory = try makeScratchDirectory()
    let url = try write(try TestFixture.rejectInvalidRole.contents(), in: directory)

    let sink = CapturingSink()
    XCTAssertEqual(
      exitCode { try ValidateCommand(path: url.path, sink: sink).run() },
      RepartoExitCode.parseError)
    XCTAssertEqual(
      sink.stderr, [errorMessage(for: CastParseError.invalidRole(index: 1, value: "star")) + "\n"])
  }

  // MARK: - canonicalize (acceptance 9)

  func testCanonicalizeParsesPathAndApplyFlag() throws {
    let command = try CanonicalizeCommand.parse(["some/CAST.md", "--apply"])
    XCTAssertEqual(command.path, "some/CAST.md")
    XCTAssertTrue(command.apply)
    XCTAssertFalse(try CanonicalizeCommand.parse(["some/CAST.md"]).apply)
  }

  func testCanonicalizeWithoutApplyChangesNothing() throws {
    let directory = try makeScratchDirectory()
    let original = castDocument([
      "- character: narrator (V.O.)\n", "- character: '@McClane'\n", "- character: GUARD\n",
    ])
    let url = try write(original, in: directory)

    let sink = CapturingSink()
    try CanonicalizeCommand(path: url.path, sink: sink).run()

    XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), original, "dry run wrote")
    XCTAssertEqual(
      sink.stdout,
      [
        "narrator (V.O.) -> NARRATOR\n",
        "@McClane -> MCCLANE\n",
        "Dry run: nothing was written. Pass --apply to rename.\n",
      ])
    XCTAssertEqual(sink.stderr, [])
  }

  func testCanonicalizeApplyRenamesAndWrites() throws {
    let directory = try makeScratchDirectory()
    let url = try write(
      castDocument([
        "- character: narrator (V.O.)\n  role: narrator\n  bio: kept\n", "- character: GUARD\n",
      ]), in: directory)

    let sink = CapturingSink()
    try CanonicalizeCommand(path: url.path, apply: true, sink: sink).run()

    let document = try CastMarkdownParser().parse(fileURL: url)
    XCTAssertEqual(document.cast.map(\.character), ["NARRATOR", "GUARD"])
    XCTAssertEqual(document.cast[0].role, .narrator)
    XCTAssertEqual(document.cast[0][extra: "bio"], try AnyCodable("kept"))
    XCTAssertEqual(document.body, "# Body stays.\n")
    XCTAssertEqual(sink.stdout, ["narrator (V.O.) -> NARRATOR\n"])
  }

  /// `--apply` is the deliberate normalizing write: it writes even when no
  /// name changes, and a second run is then a byte-for-byte no-op.
  func testCanonicalizeApplyNormalizesEvenWithNoRenames() throws {
    let directory = try makeScratchDirectory()
    let url = try write(
      "---\ntype: cast\ncast:\n- character: NARRATOR\n  voices:\n    voxalta: a.vox\n---\n",
      in: directory)

    let sink = CapturingSink()
    try CanonicalizeCommand(path: url.path, apply: true, sink: sink).run()
    let first = try String(contentsOf: url, encoding: .utf8)
    XCTAssertTrue(first.contains("schemaVersion: 1"), first)
    XCTAssertEqual(sink.stdout, ["All names are already canonical.\n"])

    try CanonicalizeCommand(path: url.path, apply: true, sink: CapturingSink()).run()
    XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), first)
  }

  func testCanonicalizeRefusesOnACollisionWithAndWithoutApply() throws {
    let directory = try makeScratchDirectory()
    let original = castDocument([
      "- character: NARRATOR\n", "- character: Narrator (V.O.)\n", "- character: GUARD\n",
    ])
    let url = try write(original, in: directory)

    for apply in [false, true] {
      let sink = CapturingSink()
      XCTAssertEqual(
        exitCode { try CanonicalizeCommand(path: url.path, apply: apply, sink: sink).run() },
        RepartoExitCode.nameCollision, "apply: \(apply)")
      XCTAssertEqual(sink.stdout, [], "apply: \(apply)")
      XCTAssertEqual(sink.stderr.count, 1)
      XCTAssertTrue(sink.stderr[0].contains("'NARRATOR', 'Narrator (V.O.)'"), sink.stderr[0])
      XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), original, "apply: \(apply)")
    }
  }

  func testCanonicalizeLeavesUncanonicalizableNamesAndWarns() throws {
    let directory = try makeScratchDirectory()
    let url = try write(
      castDocument(["- character: AC/DC\n", "- character: guard\n"]), in: directory)

    let sink = CapturingSink()
    try CanonicalizeCommand(path: url.path, apply: true, sink: sink).run()

    XCTAssertEqual(
      try CastMarkdownParser().parse(fileURL: url).cast.map(\.character), ["AC/DC", "GUARD"])
    XCTAssertEqual(sink.stderr.count, 1)
    XCTAssertTrue(sink.stderr[0].contains("'AC/DC'"))
  }

  func testCanonicalizeOfAnUnparseableFileExitsWithParseError() throws {
    let directory = try makeScratchDirectory()
    let url = try write(try TestFixture.rejectNoFrontMatter.contents(), in: directory)
    XCTAssertEqual(
      exitCode { try CanonicalizeCommand(path: url.path, sink: CapturingSink()).run() },
      RepartoExitCode.parseError)
  }

  func testCollisionMapsToTheNameCollisionExitCode() {
    XCTAssertEqual(
      repartoExitCode(for: CanonicalizationError.collision([])), RepartoExitCode.nameCollision)
    XCTAssertEqual(RepartoExitCode.nameCollision, 5)
  }

  // MARK: - import canonicalizes (RQ-22)

  private func projectDocument(_ members: [String]) -> String {
    "---\ntype: project\ntitle: Synthetic\ncast:\n" + members.joined() + "---\n"
  }

  func testImportCanonicalizesNames() throws {
    let directory = try makeScratchDirectory()
    let projectURL = try write(
      projectDocument([
        "- character: narrator (V.O.)\n  role: narrator\n", "- character: '@McClane'\n",
        "- character: 'GUARD #2'\n",
      ]), named: "PROJECT.md", in: directory)

    let sink = CapturingSink()
    try ImportCommand(projectPath: projectURL.path, sink: sink).run()

    let document = try CastMarkdownParser().parse(
      fileURL: directory.appendingPathComponent("CAST.md"))
    XCTAssertEqual(document.cast.map(\.character), ["NARRATOR", "MCCLANE", "GUARD #2"])
    XCTAssertEqual(document.cast[0].role, .narrator)
    XCTAssertEqual(sink.stderr, [])
  }

  func testImportRefusesOnACollisionAndWritesNothing() throws {
    let directory = try makeScratchDirectory()
    let projectURL = try write(
      projectDocument(["- character: NARRATOR\n", "- character: narrator (V.O.)\n"]),
      named: "PROJECT.md", in: directory)

    let sink = CapturingSink()
    XCTAssertEqual(
      exitCode { try ImportCommand(projectPath: projectURL.path, sink: sink).run() },
      RepartoExitCode.nameCollision)
    XCTAssertFalse(
      FileManager.default.fileExists(atPath: directory.appendingPathComponent("CAST.md").path))
  }

  func testImportKeepsAnUncanonicalizableNameAndWarns() throws {
    let directory = try makeScratchDirectory()
    let projectURL = try write(
      projectDocument(["- character: AC/DC\n"]), named: "PROJECT.md", in: directory)

    let sink = CapturingSink()
    try ImportCommand(projectPath: projectURL.path, dryRun: true, sink: sink).run()
    XCTAssertTrue(sink.stdout.joined().contains("character: AC/DC"), sink.stdout.joined())
    XCTAssertEqual(sink.stderr.count, 1)
  }
}
