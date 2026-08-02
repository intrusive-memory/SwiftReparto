// ProjectCastImportTests.swift
// SwiftRepartoTests
//
// Sortie 12: tests for `ProjectCastImporter` (D-4, D-7, D-13).
//
// A plain `import SwiftReparto`, never `@testable import`: importing a
// `PROJECT.md` is public API, and every field these tests read — `extraKeys` in
// particular — must be reachable through the same door a real consumer has
// (D-8), exactly like `MergeTests.swift` and `CastMemberPublicAPITests.swift`.
//
// ## The fixture is vendored, and no test reads outside this repository
//
// `Tests/Fixtures/confessions-PROJECT.md` is a trimmed but faithful excerpt of
// a real `PROJECT.md`: `type: project`, three characters with the **scalar**
// `voices` form, a ~400-character undeclared `bio:`, and the project-level
// `title` / `tts` / `episodes_index` keys that the exclusion test below exists
// to prove never reach a cast document.
//
// It is reached through `#filePath`, which the compiler resolves at build time,
// so there is no absolute path spelled anywhere in this file and no test that
// depends on a checkout living at any particular location. That is also why the
// test target needs no `resources:` declaration for it.
//
// ## `PROJECT.md` is never written (D-13)
//
// `testSourceProjectFileIsUnchangedByAnImport` hashes the vendored fixture
// before and after an import and asserts the digests match. The temporary files
// the relativization tests build are deliberately *not* named `PROJECT.md` —
// they are scratch input for the URL entry point, whose behavior depends on the
// file's directory and not on its name, and naming them otherwise keeps this
// suite from ever writing a file by that name.

import CryptoKit
import Foundation
import SwiftReparto
import XCTest

final class ProjectCastImportTests: XCTestCase {

  // MARK: - Fixture access

  /// The vendored `PROJECT.md` excerpt, located relative to this source file.
  private var confessionsProjectURL: URL {
    URL(filePath: #filePath)  // Tests/SwiftRepartoTests/ProjectCastImportTests.swift
      .deletingLastPathComponent()  // Tests/SwiftRepartoTests
      .deletingLastPathComponent()  // Tests
      .appending(path: "Fixtures")
      .appending(path: "confessions-PROJECT.md")
  }

  /// A fresh, empty directory under the system temporary directory, removed
  /// when the test finishes.
  private func makeScratchDirectory() throws -> URL {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
      .appending(path: "SwiftRepartoImport-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    addTeardownBlock {
      try? FileManager.default.removeItem(at: directory)
    }
    return directory
  }

  private func sha256(ofFileAt url: URL) throws -> String {
    let data = try Data(contentsOf: url)
    return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }

  // MARK: - The whole roster arrives

  func testImportYieldsEveryMemberInDocumentOrder() throws {
    let document = try ProjectCastImporter().importCast(fileURL: confessionsProjectURL)

    XCTAssertEqual(
      document.cast.map(\.character),
      ["NARRATOR", "ESPECTRO FAMILIAR", "THE PRACTITIONER"])
  }

  func testImportedMembersCarryTheirVoicePrompts() throws {
    let document = try ProjectCastImporter().importCast(fileURL: confessionsProjectURL)

    XCTAssertEqual(
      document.cast.first?.voicePrompt,
      "Deep authoritative British baritone. Warm, commanding documentary narrator. "
        + "Rich resonance, measured pacing.")
  }

  // MARK: - RQ-3: the scalar `voices` form survives (criterion 3)

  func testScalarVoicesFormDecodesOnTheImportPath() throws {
    let document = try ProjectCastImporter().importCast(fileURL: confessionsProjectURL)

    // Every member in the fixture writes `voxalta: <path>` as a bare scalar.
    // The same `CastMember` decoder `parse` uses turns each into a one-element
    // array, which is what proves there is no second decoder here.
    XCTAssertEqual(
      document.cast.map(\.voices),
      [
        ["voxalta": ["voices/NARRATOR.vox"]],
        ["voxalta": ["voices/ESPECTRO_FAMILIAR.vox"]],
        ["voxalta": ["voices/THE_PRACTITIONER.vox"]],
      ])
  }

  // MARK: - RQ-4: `bio` survives (criterion 3)

  func testUndeclaredBioKeySurvivesTheImport() throws {
    let document = try ProjectCastImporter().importCast(fileURL: confessionsProjectURL)

    let practitioner = try XCTUnwrap(document.cast.first { $0.character == "THE PRACTITIONER" })
    let bio = try XCTUnwrap(practitioner[extra: "bio"]).decode(String.self)

    XCTAssertTrue(bio.hasPrefix("Neurodivergent (ADHD), gay Gen X developer in his late forties"))
    XCTAssertTrue(bio.hasSuffix("Brings the wound; asks the questions."))
    XCTAssertGreaterThan(bio.count, 400)
  }

  func testUndeclaredBioKeySurvivesEmission() throws {
    let document = try ProjectCastImporter().importCast(fileURL: confessionsProjectURL)
    let emitted = try CastMarkdownParser().generate(document: document)

    XCTAssertTrue(emitted.contains("bio:"))
    XCTAssertTrue(emitted.contains("Brings the wound; asks the questions."))
  }

  // MARK: - D-7: relative paths come through unchanged (criterion 4)

  func testAlreadyRelativeVoicePathsAreUnchangedByTheImport() throws {
    let document = try ProjectCastImporter().importCast(fileURL: confessionsProjectURL)

    // A string comparison, not a "still relative" predicate: `CAST.md` is
    // written beside `PROJECT.md`, so the two share a base directory and there
    // is nothing for the relativization pass to rewrite. Anything other than
    // the exact source spelling here is a bug.
    XCTAssertEqual(document.cast[0].voices["voxalta"], ["voices/NARRATOR.vox"])
    XCTAssertEqual(document.cast[1].voices["voxalta"], ["voices/ESPECTRO_FAMILIAR.vox"])
    XCTAssertEqual(document.cast[2].voices["voxalta"], ["voices/THE_PRACTITIONER.vox"])
  }

  // MARK: - D-7: absolute paths under the source directory are relativized (criterion 5)

  func testAbsoluteVoicePathUnderTheProjectDirectoryIsRelativized() throws {
    let directory = try makeScratchDirectory()
    let source = directory.appending(path: "project-under-test.md")
    let absolutePath = directory.appending(path: "voices/NARRATOR.vox").path(percentEncoded: false)

    try """
    ---
    type: project
    title: Scratch
    cast:
      - character: NARRATOR
        voices:
          voxalta: \(absolutePath)
    ---

    Body prose.
    """.write(to: source, atomically: true, encoding: .utf8)

    let document = try ProjectCastImporter().importCast(fileURL: source)

    XCTAssertEqual(document.cast[0].voices["voxalta"], ["voices/NARRATOR.vox"])
  }

  func testAbsoluteVoicePathOutsideTheProjectDirectoryIsLeftAlone() throws {
    let directory = try makeScratchDirectory()
    let source = directory.appending(path: "project-under-test.md")

    // A sibling directory whose name *begins* with the base directory's name.
    // The shared relativization function's trailing-separator normalization is
    // what stops this from matching the prefix, and this is its regression
    // test on the import path.
    let siblingPath =
      directory
      .deletingLastPathComponent()
      .appending(path: directory.lastPathComponent + "-backup")
      .appending(path: "NARRATOR.vox")
      .path(percentEncoded: false)

    try """
    ---
    type: project
    cast:
      - character: NARRATOR
        voices:
          voxalta: \(siblingPath)
    ---
    """.write(to: source, atomically: true, encoding: .utf8)

    let document = try ProjectCastImporter().importCast(fileURL: source)

    XCTAssertEqual(document.cast[0].voices["voxalta"], [siblingPath])
  }

  func testContentEntryPointDoesNotRelativize() throws {
    // Matching `parse(content:)`: a bare `String` has no directory, so absolute
    // paths are the caller's responsibility and are carried verbatim (D-7).
    let content = """
      ---
      type: project
      cast:
        - character: NARRATOR
          voices:
            voxalta: /Volumes/Media/confessions/voices/NARRATOR.vox
      ---
      """

    let document = try ProjectCastImporter().importCast(content: content)

    XCTAssertEqual(
      document.cast[0].voices["voxalta"],
      ["/Volumes/Media/confessions/voices/NARRATOR.vox"])
  }

  // MARK: - Criterion 6: no project-level key reaches the document

  func testNoProjectLevelKeyAppearsInTheImportedDocument() throws {
    let document = try ProjectCastImporter().importCast(fileURL: confessionsProjectURL)
    let emitted = try CastMarkdownParser().generate(document: document)

    // Keys, and the values behind them. Both, because a key could be dropped
    // while its value rode in on some other name.
    for forbidden in [
      // `author` is checked with its colon on purpose: the bare substring
      // occurs inside NARRATOR's own `voicePrompt` ("authoritative"), and a
      // test that fails on real cast prose is a test nobody trusts.
      "title", "tts", "episodes_index", "episodesDir", "audioDir", "author:", "keywords",
      "summary", "Confessions of a Software Spellcaster", "Tom Stovall", "1.7b", "CODE REVIEW",
      "STOIC REFRAMING", "type: project",
    ] {
      XCTAssertFalse(
        emitted.contains(forbidden),
        "Emitted cast document leaked the project-level content '\(forbidden)'.")
    }

    // And nothing project-level was swept into a member's undeclared keys
    // either — `ProjectCastBlock` declares one coding key, and this asserts it.
    XCTAssertEqual(document.cast.map { Set($0.extraKeys.keys) }, [[], [], ["bio"]])
  }

  func testImportedDocumentHasAnEmptyBody() throws {
    // Task 6: a `PROJECT.md`'s markdown is project prose, not cast prose, and
    // RQ-8 forbids this library from generating body content of its own. The
    // human writes the `# Cast` narrative afterward.
    let document = try ProjectCastImporter().importCast(fileURL: confessionsProjectURL)

    XCTAssertEqual(document.body, "")
  }

  // MARK: - Criterion 7: the imported document emits as a valid, versioned `CAST.md`

  func testImportedDocumentIsStampedWithTheCurrentSchemaVersion() throws {
    let document = try ProjectCastImporter().importCast(fileURL: confessionsProjectURL)

    XCTAssertEqual(document.schemaVersion, CastSchemaVersion.current)
    XCTAssertFalse(document.isUnversioned)
  }

  func testEmittedImportRoundTripsThroughTheParser() throws {
    let imported = try ProjectCastImporter().importCast(fileURL: confessionsProjectURL)
    let parser = CastMarkdownParser()
    let emitted = try parser.generate(document: imported)

    XCTAssertTrue(emitted.contains("type: cast"))
    XCTAssertTrue(emitted.contains("schemaVersion: \(CastSchemaVersion.current)"))

    let reparsed = try parser.parse(content: emitted)

    XCTAssertEqual(reparsed.schemaVersion, CastSchemaVersion.current)
    XCTAssertEqual(reparsed.cast, imported.cast)
  }

  // MARK: - Criterion 8 / D-13: the source file is never written

  func testSourceProjectFileIsUnchangedByAnImport() throws {
    let before = try sha256(ofFileAt: confessionsProjectURL)

    _ = try ProjectCastImporter().importCast(fileURL: confessionsProjectURL)

    let after = try sha256(ofFileAt: confessionsProjectURL)

    XCTAssertEqual(
      before, after,
      "Importing a PROJECT.md must leave it byte-for-byte as it was found (D-13).")
  }

  // MARK: - Criterion 9: typed errors, never an empty roster

  func testFrontMatterWithoutACastKeyThrowsMissingCastKey() throws {
    let content = """
      ---
      type: project
      title: Confessions of a Software Spellcaster
      tts:
        model: 1.7b
      ---

      # Confessions of a Software Spellcaster
      """

    XCTAssertThrowsError(try ProjectCastImporter().importCast(content: content)) { error in
      // The distinction RQ-12 exists to preserve: "this file describes no
      // roster" is not "this file describes an empty roster".
      XCTAssertEqual(error as? CastParseError, .missingCastKey)
    }
  }

  func testAnEmptyCastArrayIsAnEmptyRosterRatherThanAnError() throws {
    let content = """
      ---
      type: project
      title: Scratch
      cast: []
      ---
      """

    let document = try ProjectCastImporter().importCast(content: content)

    XCTAssertTrue(document.cast.isEmpty)
  }

  func testContentWithNoFrontMatterThrowsNoFrontMatter() throws {
    XCTAssertThrowsError(
      try ProjectCastImporter().importCast(content: "# Just markdown\n\nNo front matter here.\n")
    ) { error in
      XCTAssertEqual(error as? CastParseError, .noFrontMatter)
    }
  }

  func testUnterminatedFrontMatterThrowsNoFrontMatter() throws {
    // No closing delimiter is a truncated file, not front matter running to end
    // of file — the reader's rule, applied identically on the import path.
    XCTAssertThrowsError(
      try ProjectCastImporter().importCast(content: "---\ntype: project\ncast: []\n")
    ) { error in
      XCTAssertEqual(error as? CastParseError, .noFrontMatter)
    }
  }

  func testMemberWithoutACharacterFieldReportsItsIndex() throws {
    let content = """
      ---
      type: project
      cast:
        - character: NARRATOR
        - voicePrompt: "Nameless."
      ---
      """

    XCTAssertThrowsError(try ProjectCastImporter().importCast(content: content)) { error in
      XCTAssertEqual(error as? CastParseError, .missingCharacter(index: 1))
    }
  }

  func testFrontMatterThatIsNotYAMLThrowsInvalidYAML() throws {
    let content = """
      ---
      type: project
      cast: [ unclosed
      ---
      """

    XCTAssertThrowsError(try ProjectCastImporter().importCast(content: content)) { error in
      guard case .invalidYAML? = error as? CastParseError else {
        XCTFail("Expected .invalidYAML, got \(error).")
        return
      }
    }
  }

  // MARK: - Line endings

  func testCRLFFrontMatterImports() throws {
    // CRLF is one `Character` in Swift, which is the trap a line scanner
    // written over the `Character` view has to be built for rather than to fall
    // into. This is that regression test on the import path.
    let content = "---\r\ntype: project\r\ncast:\r\n  - character: NARRATOR\r\n---\r\n\r\nBody.\r\n"

    let document = try ProjectCastImporter().importCast(content: content)

    XCTAssertEqual(document.cast.map(\.character), ["NARRATOR"])
    XCTAssertEqual(document.body, "")
  }

  // MARK: - RQ-3: the legacy `voiceDescription` key, on the import path

  func testLegacyVoiceDescriptionKeyDecodesOnTheImportPath() throws {
    let content = """
      ---
      type: project
      cast:
        - character: NARRATOR
          voiceDescription: "Deep authoritative British baritone."
      ---
      """

    let document = try ProjectCastImporter().importCast(content: content)

    XCTAssertEqual(document.cast[0].voicePrompt, "Deep authoritative British baritone.")
    XCTAssertNil(document.cast[0][extra: "voiceDescription"])
  }
}
