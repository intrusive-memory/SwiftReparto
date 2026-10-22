// AcceptanceGateTests.swift
// SwiftRepartoTests
//
// Sortie 14: proves REQUIREMENTS.md §8's acceptance criteria 2, 3, 4, and 5
// directly against the pinned fixtures under `Fixtures/` (Sortie 13), plus
// RQ-11's legacy-unversioned path (D-5/D-12) and the import pipeline's
// front-matter identity (D-4/D-7).
//
// A plain `import SwiftReparto`, never `@testable import` (D-8): acceptance
// criterion 3's `bio` read goes through `subscript(extra:)`, the exact door a
// real consumer has, matching `FixtureIntegrityTests.swift` and
// `ProjectCastImportTests.swift`.
//
// This file writes nothing under `Fixtures/`. The mutate-and-write cycle below
// copies the pinned fixture's *contents* into a scratch temporary directory
// first; the bytes under `Fixtures/` are never touched.

import CryptoKit
import Foundation
import SwiftReparto
import XCTest

final class AcceptanceGateTests: XCTestCase {

  private let parser = CastMarkdownParser()

  private func sha256(_ string: String) -> String {
    SHA256.hash(data: Data(string.utf8)).map { String(format: "%02x", $0) }.joined()
  }

  // MARK: - Scratch files (never under Fixtures/, per this sortie's boundaries)

  private func makeScratchDirectory() throws -> URL {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
      .appending(path: "SwiftRepartoAcceptance-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    addTeardownBlock {
      try? FileManager.default.removeItem(at: directory)
    }
    return directory
  }

  /// Raised only if a generated document does not have the shape
  /// `CastMarkdownGenerator.generate(document:)` guarantees. Never expected to
  /// fire; it exists so a slicing mistake reads as a named failure rather than
  /// an index-out-of-range crash.
  private struct FrontMatterSliceError: Error, CustomStringConvertible {
    let description: String
  }

  /// The front-matter region of a generated (or fixture) `CAST.md` string:
  /// everything up to and including the closing `---` line and its trailing
  /// newline, and nothing of whatever follows.
  ///
  /// `CastMarkdownGenerator.generate(document:)` always produces
  /// `"---\n" + frontMatter + "---\n" + body`, where `frontMatter` itself
  /// already ends in `"\n"`. So the closing delimiter is always reachable as
  /// the first `"\n---\n"` after the opening delimiter's own four bytes, and
  /// slicing up to (and including) that match's upper bound yields exactly
  /// `"---\n" + frontMatter + "---\n"` — front matter plus both delimiters,
  /// with no byte of the body included.
  private func frontMatterRegion(of content: String) throws -> String {
    guard content.hasPrefix("---\n") else {
      throw FrontMatterSliceError(description: "no opening delimiter: \(content.prefix(40))")
    }
    let searchStart = content.index(content.startIndex, offsetBy: 4)
    guard let closing = content.range(of: "\n---\n", range: searchStart..<content.endIndex) else {
      throw FrontMatterSliceError(description: "no closing delimiter found")
    }
    return String(content[content.startIndex..<closing.upperBound])
  }

  // MARK: - Acceptance criterion 2: confessions-CAST.md round-trips by SHA-256

  /// `SHA256(generate(parse(confessions-CAST.md))) == SHA256(confessions-CAST.md)`.
  func testConfessionsCastFixtureSHA256IsUnchangedAcrossParseAndGenerate() throws {
    let original = try TestFixture.confessionsCastMD.contents()
    let regenerated = try parser.generate(document: try parser.parse(content: original))

    XCTAssertEqual(sha256(regenerated), sha256(original))
    XCTAssertEqual(Array(regenerated.utf8), Array(original.utf8))
  }

  // MARK: - Acceptance criterion 3: `bio` preserved, by name, through the public API

  /// Parses the pinned fixture, locates THE PRACTITIONER, and reads `bio` back
  /// out through `subscript(extra:)` — the public door (D-8) — comparing it to
  /// the fixture's own literal value byte-for-byte.
  ///
  /// The literal below was transcribed directly from
  /// `Fixtures/confessions-CAST.md`'s `bio:` value (itself sourced from
  /// `Fixtures/confessions-PROJECT.md`, whose `bio:` is the same text under
  /// double quotes rather than single) — asserted a second way just below by
  /// cross-checking against that sibling fixture's own decoded value, so a
  /// transcription slip in this literal cannot silently pass.
  func testThePractitionersBioMatchesTheFixturesLiteralValue() throws {
    let document = try parser.parse(content: try TestFixture.confessionsCastMD.contents())
    let practitioner = try XCTUnwrap(document.cast.first { $0.character == "THE PRACTITIONER" })

    let bio = try XCTUnwrap(practitioner[extra: "bio"]).decode(String.self)

    let expectedBio =
      "Neurodivergent (ADHD), gay Gen X developer in his late forties, anchored in the "
      + "Coachella Valley. Came of age in the eighties and nineties: MTV, Madonna and Whitney "
      + "Houston, Reagan, and the AIDS crisis. Watched a generation of friends die or disappear; "
      + "carries that loss into how he thinks about community, mortality, eldership, and chosen "
      + "family. The bridge generation — analog childhood, digital adulthood. Brings the wound; "
      + "asks the questions."

    XCTAssertEqual(bio, expectedBio)

    // Cross-check: the sibling PROJECT.md fixture carries the identical text
    // under a different YAML quoting style. If the literal above were
    // mistyped, this independent comparison — sourced from a second pinned
    // fixture rather than from this file — would still catch it.
    let imported = try ProjectCastImporter().importCast(
      fileURL: try TestFixture.confessionsProjectMD.url())
    let importedPractitioner = try XCTUnwrap(
      imported.cast.first { $0.character == "THE PRACTITIONER" })
    let importedBio = try XCTUnwrap(importedPractitioner[extra: "bio"]).decode(String.self)

    XCTAssertEqual(bio, importedBio)
  }

  // MARK: - Acceptance criterion 4: body survives a mutate-and-write cycle, against the fixture

  /// Copies the pinned fixture's bytes into a scratch file, mutates
  /// `cast[0].voices`, writes it back, and confirms the body's SHA-256 is
  /// unchanged. The scratch copy is written under a temporary directory, never
  /// under `Fixtures/`.
  func testBodySurvivesAMutateAndWriteCycleAgainstThePinnedFixture() throws {
    let originalContents = try TestFixture.confessionsCastMD.contents()
    let originalBody = try parser.parse(content: originalContents).body

    let directory = try makeScratchDirectory()
    let fileURL = directory.appending(path: "CAST.md")
    try Data(originalContents.utf8).write(to: fileURL)

    var document = try parser.parse(fileURL: fileURL)
    document.cast[0].voices["voxalta"] = ["voices/NARRATOR-updated.vox"]
    try parser.write(document: document, to: fileURL)

    let rewrittenBody = try parser.parse(fileURL: fileURL).body

    XCTAssertEqual(sha256(rewrittenBody), sha256(originalBody))
    XCTAssertEqual(Array(rewrittenBody.utf8), Array(originalBody.utf8))

    // And the mutation actually landed, so an accidental no-op does not
    // disguise itself as a pass.
    XCTAssertEqual(
      try parser.parse(fileURL: fileURL).cast[0].voices["voxalta"],
      ["voices/NARRATOR-updated.vox"])
  }

  // MARK: - Legacy data (RQ-25): `appearance:` round-trips byte-identically through `extraKeys`

  /// `all-fields-CAST.md`'s nested `appearance:` block is a legacy,
  /// never-declared key (RQ-25, superseding D-3), so the whole document —
  /// block included — must be a byte fixed point across a parse/generate
  /// cycle. Acceptance criterion 8's round-trip half.
  func testAppearanceBlockInAllFieldsFixtureRoundTripsByteIdentically() throws {
    let original = try TestFixture.allFieldsCastMD.contents()
    XCTAssertTrue(original.contains("appearance:"), "fixture must exercise D-3's deferral")

    let regenerated = try parser.generate(document: try parser.parse(content: original))

    XCTAssertEqual(sha256(regenerated), sha256(original))
    XCTAssertEqual(Array(regenerated.utf8), Array(original.utf8))
  }

  /// The other half of the standing proof: a member with no `appearance:`
  /// gains none on re-emit. `all-fields-CAST.md` has exactly one member (the
  /// one carrying `appearance:`), so this builds a second, appearance-free
  /// member in memory rather than adding a fixture — this sortie adds nothing
  /// under `Fixtures/`.
  func testMemberWithNoAppearanceGainsNoneOnReEmit() throws {
    let member = CastMember(character: "SILENT EXTRA")
    let document = CastDocument(cast: [member], body: "")

    let emitted = try parser.generate(document: document)

    XCTAssertFalse(emitted.contains("appearance"), emitted)
    XCTAssertTrue(try parser.parse(content: emitted).cast[0].extraKeys.isEmpty)
  }

  // MARK: - Acceptance criterion 5: legacy `voiceDescription` and scalar `voices`

  /// `legacy-unversioned-CAST.md`'s NARRATOR entry carries the legacy
  /// `voiceDescription:` key. Reused rather than authoring a new fixture
  /// (per this sortie's directive B) — it already isolates the case on its
  /// own small, pinned document.
  func testLegacyVoiceDescriptionKeyDecodesFromItsOwnFixture() throws {
    let document = try parser.parse(content: try TestFixture.legacyUnversionedCastMD.contents())
    let narrator = try XCTUnwrap(document.cast.first { $0.character == "NARRATOR" })

    XCTAssertEqual(narrator.voicePrompt, "Deep authoritative British baritone.")
    XCTAssertNil(narrator[extra: "voiceDescription"])
  }

  /// The same fixture's NARRATOR entry writes `voices` as a bare scalar
  /// (`voxalta: voices/NARRATOR.vox`), decoding to the one-element array form.
  func testScalarVoicesFormDecodesFromItsOwnFixture() throws {
    let document = try parser.parse(content: try TestFixture.legacyUnversionedCastMD.contents())
    let narrator = try XCTUnwrap(document.cast.first { $0.character == "NARRATOR" })

    XCTAssertEqual(narrator.voices, ["voxalta": ["voices/NARRATOR.vox"]])
  }

  // MARK: - The legacy-unversioned path, end to end (D-5/D-12)

  /// `legacy-unversioned-CAST.md` parses, carries the unversioned sentinel,
  /// emits with the current version stamped, and the *second* emission
  /// (parse-then-generate the first emission) is byte-stable against the
  /// first.
  ///
  /// This deliberately does not compare either emission back to the original
  /// unversioned bytes — that fixture is not in emitted form and this library
  /// never claims to reproduce it; RQ-11 scopes identity to documents this
  /// library emitted. Comparing emission N to emission N+1 is the shape that
  /// tests what the legacy path actually promises.
  func testLegacyUnversionedFixtureIsStampedOnFirstWriteAndStableOnTheSecond() throws {
    let document = try parser.parse(content: try TestFixture.legacyUnversionedCastMD.contents())

    XCTAssertTrue(document.isUnversioned)
    XCTAssertEqual(document.schemaVersion, CastSchemaVersion.unversioned)

    let firstEmission = try parser.generate(document: document)
    XCTAssertTrue(firstEmission.contains("\nschemaVersion: \(CastSchemaVersion.current)\n"))

    let reparsed = try parser.parse(content: firstEmission)
    XCTAssertFalse(reparsed.isUnversioned)
    XCTAssertEqual(reparsed.schemaVersion, CastSchemaVersion.current)

    let secondEmission = try parser.generate(document: reparsed)

    XCTAssertEqual(sha256(secondEmission), sha256(firstEmission))
    XCTAssertEqual(Array(secondEmission.utf8), Array(firstEmission.utf8))
  }

  // MARK: - The full import pipeline: front matter only, by SHA-256 (D-4, D-7)

  /// `confessions-PROJECT.md` -> import -> generate produces a front-matter
  /// region equal, by SHA-256, to the pinned `confessions-CAST.md`'s own
  /// front-matter region.
  ///
  /// The import path sets `body` to the empty string (RQ-INV-3/D-4), so
  /// `generate` on the imported document is front matter and nothing else —
  /// its entire output already *is* the front-matter region. `CAST.md`'s
  /// fixture carries a hand-written body after its own front matter, so the
  /// comparison is deliberately sliced to the region both sides actually
  /// share: everything through the closing `---` line and its trailing
  /// newline (see `frontMatterRegion(of:)`, above).
  func testImportedFrontMatterMatchesThePinnedCastFixturesFrontMatter() throws {
    let imported = try ProjectCastImporter().importCast(
      fileURL: try TestFixture.confessionsProjectMD.url())
    XCTAssertEqual(imported.body, "")

    let importedOutput = try parser.generate(document: imported)
    let pinnedOutput = try TestFixture.confessionsCastMD.contents()

    let importedFrontMatter = try frontMatterRegion(of: importedOutput)
    let pinnedFrontMatter = try frontMatterRegion(of: pinnedOutput)

    // The imported document has no body, so its whole generated output is
    // exactly its front-matter region — the slice changes nothing on this
    // side, which is worth asserting explicitly.
    XCTAssertEqual(importedFrontMatter, importedOutput)

    XCTAssertEqual(sha256(importedFrontMatter), sha256(pinnedFrontMatter))
    XCTAssertEqual(Array(importedFrontMatter.utf8), Array(pinnedFrontMatter.utf8))
  }
}
