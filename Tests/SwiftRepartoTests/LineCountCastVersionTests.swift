// LineCountCastVersionTests.swift
// SwiftRepartoTests
//
// `CastMember.lineCount` (RQ-26, D-15, RP-P17) and `CastDocument.castVersion`
// (RQ-27, RP-P18): parse, generate, round-trip, strict decoding, the
// replace-on-merge rule, and the proof that documents without either key are
// unchanged. REQUIREMENTS.md §5 acceptance criteria 10 to 14. Synthetic data
// only.
//
// A plain `import SwiftReparto`: every API exercised here is public.

import CryptoKit
import Foundation
import SwiftReparto
import XCTest

final class LineCountCastVersionTests: XCTestCase {

  private let parser = CastMarkdownParser()

  private func sha256(_ string: String) -> String {
    SHA256.hash(data: Data(string.utf8)).map { String(format: "%02x", $0) }.joined()
  }

  private func document(frontMatter: String = "", _ memberYAML: String) -> String {
    "---\ntype: cast\nschemaVersion: 1\n\(frontMatter)cast:\n\(memberYAML)---\n\nBody.\n"
  }

  /// The fixtures written before RQ-26 / RQ-27 that are already in emitted
  /// form, so each is a byte fixed point under RQ-11. (`elevenlabs-voices-CAST.md`
  /// is hand-written, not emitted form, so RQ-11 does not apply to it; its own
  /// suite compares parsed values.)
  private let preLineCountEmittedFixtures: [TestFixture] = [
    .confessionsCastMD, .allFieldsCastMD, .roleManifestCastMD,
  ]

  // MARK: - Defaults

  func testBothDefaultToNil() {
    XCTAssertNil(CastMember(character: "ALPHA").lineCount)
    XCTAssertNil(CastDocument().castVersion)
  }

  func testSchemaVersionIsStillOne() {
    XCTAssertEqual(CastSchemaVersion.current, 1, "D-15 / RQ-27: no schema version bump")
  }

  // MARK: - Acceptance 10 and 14: the pinned fixture

  func testFixtureDecodesIntoTypedFields() throws {
    let document = try parser.parse(content: try TestFixture.lineCountCastVersionCastMD.contents())
    XCTAssertEqual(document.castVersion, 57)
    XCTAssertEqual(document.cast.map(\.lineCount), [40, 12, 0, nil])
    for member in document.cast {
      XCTAssertNil(member[extra: "lineCount"], "lineCount is declared, never an extra")
    }
    XCTAssertEqual(
      document.cast[0][extra: "bio"].map { try? $0.decode(String.self) } ?? nil,
      "A fictional practitioner who exists only in this test fixture.")
  }

  func testFixtureRoundTripsByteForByte() throws {
    let original = try TestFixture.lineCountCastVersionCastMD.contents()
    let regenerated = try parser.generate(document: try parser.parse(content: original))
    XCTAssertEqual(sha256(regenerated), sha256(original), regenerated)
  }

  func testFixtureRoundTripsThroughAFile() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("LineCountCastVersionTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("CAST.md")

    let original = try TestFixture.lineCountCastVersionCastMD.contents()
    try parser.write(document: try parser.parse(content: original), to: url)
    let reread = try parser.parse(fileURL: url)
    XCTAssertEqual(reread.castVersion, 57)
    XCTAssertEqual(reread.cast.map(\.lineCount), [40, 12, 0, nil])
    XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), original)
  }

  // MARK: - Generation and emission position

  func testLineCountEncodesAfterDisplayNameAndBeforeSortedExtras() throws {
    var member = CastMember(
      character: "ALPHA", manifest: "characters/ALPHA.dossier/manifest.json",
      displayName: "Alpha Prime", lineCount: 7)
    member.setExtra(try AnyCodable("x"), forKey: "aardvark")
    let emitted = try parser.generate(document: CastDocument(cast: [member]))
    let displayAt = try XCTUnwrap(emitted.range(of: "displayName:")).lowerBound
    let countAt = try XCTUnwrap(emitted.range(of: "lineCount: 7\n")).lowerBound
    let extraAt = try XCTUnwrap(emitted.range(of: "aardvark:")).lowerBound
    XCTAssertLessThan(displayAt, countAt)
    XCTAssertLessThan(countAt, extraAt)
  }

  func testCastVersionEncodesAfterSchemaVersionAndBeforeCast() throws {
    let emitted = try parser.generate(
      document: CastDocument(cast: [CastMember(character: "ALPHA")], castVersion: 57))
    XCTAssertTrue(
      emitted.hasPrefix("---\ntype: cast\nschemaVersion: 1\ncastVersion: 57\ncast:\n"), emitted)
  }

  func testZeroIsWrittenNotOmitted() throws {
    let emitted = try parser.generate(
      document: CastDocument(cast: [CastMember(character: "ALPHA", lineCount: 0)], castVersion: 0))
    XCTAssertTrue(emitted.contains("castVersion: 0\n"))
    XCTAssertTrue(emitted.contains("lineCount: 0\n"))
    let reparsed = try parser.parse(content: emitted)
    XCTAssertEqual(reparsed.castVersion, 0)
    XCTAssertEqual(reparsed.cast.first?.lineCount, 0, "absent is not 0, and 0 is not absent")
  }

  func testInMemoryValuesRoundTrip() throws {
    let original = CastDocument(
      cast: [CastMember(character: "ALPHA", lineCount: 312), CastMember(character: "BETA")],
      body: "Body.\n", castVersion: 1204)
    let reparsed = try parser.parse(content: try parser.generate(document: original))
    XCTAssertEqual(reparsed, original)
  }

  // MARK: - Absence: acceptance 11 and 14 (no key in, no key out)

  func testNilValuesEmitNoKey() throws {
    let emitted = try parser.generate(
      document: CastDocument(cast: [CastMember(character: "ALPHA")], body: ""))
    XCTAssertFalse(emitted.contains("lineCount"))
    XCTAssertFalse(emitted.contains("castVersion"))
  }

  func testDocumentsWithoutEitherKeyLoadAsNilAndAreByteFixedPoints() throws {
    for fixture in preLineCountEmittedFixtures {
      let original = try fixture.contents()
      XCTAssertFalse(original.contains("lineCount"), fixture.rawValue)
      XCTAssertFalse(original.contains("castVersion"), fixture.rawValue)

      let parsed = try parser.parse(content: original)
      XCTAssertNil(parsed.castVersion, fixture.rawValue)
      XCTAssertTrue(parsed.cast.allSatisfy { $0.lineCount == nil }, fixture.rawValue)

      let regenerated = try parser.generate(document: parsed)
      XCTAssertEqual(sha256(regenerated), sha256(original), fixture.rawValue)
    }
  }

  // MARK: - Acceptance 12 and 14: strict decoding

  func testNegativeLineCountFailsWithInvalidLineCount() throws {
    let content = try TestFixture.rejectInvalidLineCount.contents()
    XCTAssertThrowsError(try parser.parse(content: content)) { error in
      XCTAssertEqual(error as? CastParseError, .invalidLineCount(index: 1, value: "-1"))
    }
  }

  func testNonIntegerLineCountsFailWithInvalidLineCount() throws {
    let bad: [(yaml: String, reported: String)] = [
      ("many", "many"), ("'12'", "12"), ("012", "012"), ("1.5", "1.5"), ("true", "true"),
    ]
    for (yaml, reported) in bad {
      let content = document("  - character: ALPHA\n    lineCount: \(yaml)\n")
      XCTAssertThrowsError(try parser.parse(content: content), yaml) { error in
        XCTAssertEqual(
          error as? CastParseError, .invalidLineCount(index: 0, value: reported), yaml)
      }
    }
  }

  func testNonScalarLineCountFailsWithInvalidLineCount() throws {
    let content = document("  - character: ALPHA\n    lineCount: [1, 2]\n")
    XCTAssertThrowsError(try parser.parse(content: content)) { error in
      guard case .invalidLineCount(index: 0, value: _) = error as? CastParseError else {
        return XCTFail("\(error)")
      }
    }
  }

  func testInvalidLineCountFailsOnTheImportPathToo() throws {
    let content = "---\ntype: project\ncast:\n- character: NARRATOR\n  lineCount: many\n---\n"
    XCTAssertThrowsError(try ProjectCastImporter().importCast(content: content)) { error in
      XCTAssertEqual(error as? CastParseError, .invalidLineCount(index: 0, value: "many"))
    }
  }

  func testInvalidCastVersionsFailWithInvalidCastVersion() throws {
    let bad: [(yaml: String, reported: String)] = [
      ("-1", "-1"), ("many", "many"), ("'57'", "57"), ("057", "057"),
    ]
    for (yaml, reported) in bad {
      let content = document(frontMatter: "castVersion: \(yaml)\n", "  - character: ALPHA\n")
      XCTAssertThrowsError(try parser.parse(content: content), yaml) { error in
        XCTAssertEqual(error as? CastParseError, .invalidCastVersion(value: reported), yaml)
      }
    }
  }

  func testNullValuesReadAsAbsent() throws {
    let content = document(
      frontMatter: "castVersion: null\n", "  - character: ALPHA\n    lineCount: ~\n")
    let parsed = try parser.parse(content: content)
    XCTAssertNil(parsed.castVersion)
    XCTAssertNil(parsed.cast.first?.lineCount)
  }

  /// Outside a document there is no index to report, so a standalone member
  /// decode surfaces an ordinary `DecodingError`.
  func testStandaloneMemberDecodeWithBadLineCountThrowsDecodingError() {
    let json = Data(#"{"character": "NARRATOR", "lineCount": -4}"#.utf8)
    XCTAssertThrowsError(try JSONDecoder().decode(CastMember.self, from: json)) { error in
      XCTAssertTrue(error is DecodingError, "\(error)")
    }
  }

  // MARK: - Migration from extras (RQ-26)

  /// A document a newer writer produced while `lineCount` was undeclared
  /// carries it as an extra, sorted among the extras. It loads straight into
  /// the typed field, and the first write may move the key (normalizing
  /// write); the value never changes, and the result is then a fixed point.
  func testLineCountWrittenAsAnExtraLoadsIntoTheDeclaredField() throws {
    let legacy = document("  - character: ALPHA\n    voices: {}\n    bio: kept\n    lineCount: 9\n")
    let parsed = try parser.parse(content: legacy)
    let member = try XCTUnwrap(parsed.cast.first)
    XCTAssertEqual(member.lineCount, 9)
    XCTAssertNil(member[extra: "lineCount"])
    XCTAssertEqual(member.extraKeys.keys.sorted(), ["bio"])

    let first = try parser.generate(document: parsed)
    XCTAssertEqual(try parser.parse(content: first), parsed)
    XCTAssertEqual(try parser.generate(document: try parser.parse(content: first)), first)
  }

  // MARK: - Acceptance 13: merge replaces lineCount

  func testMergeReplacesAnExistingLineCount() {
    let receiver = [CastMember(character: "ALPHA", lineCount: 12)]
    let discovered = [CastMember(character: "ALPHA", lineCount: 40)]
    XCTAssertEqual(receiver.merging(discovered).first?.lineCount, 40)
  }

  func testMergeFillsAMissingLineCount() {
    let receiver = [CastMember(character: "ALPHA")]
    let discovered = [CastMember(character: "ALPHA", lineCount: 40)]
    XCTAssertEqual(receiver.merging(discovered).first?.lineCount, 40)
  }

  func testMergeWithNilIncomingKeepsTheReceiversLineCount() {
    let receiver = [CastMember(character: "ALPHA", lineCount: 12)]
    let discovered = [CastMember(character: "ALPHA")]
    XCTAssertEqual(receiver.merging(discovered).first?.lineCount, 12)
  }

  func testMergeReplacesWithZero() {
    let receiver = [CastMember(character: "ALPHA", lineCount: 12)]
    let discovered = [CastMember(character: "ALPHA", lineCount: 0)]
    XCTAssertEqual(receiver.merging(discovered).first?.lineCount, 0)
  }

  func testMergeMatchesOnCanonicalNameAndKeepsTheReceiversCharacter() {
    let receiver = [CastMember(character: "Narrator", lineCount: 12)]
    let discovered = [CastMember(character: "NARRATOR (V.O.)", lineCount: 40)]
    let merged = receiver.merging(discovered)
    XCTAssertEqual(merged.count, 1)
    XCTAssertEqual(merged.first?.character, "Narrator")
    XCTAssertEqual(merged.first?.lineCount, 40)
  }

  func testNewMembersArriveWithTheirLineCount() {
    let receiver = [CastMember(character: "ALPHA", lineCount: 3)]
    let discovered = [CastMember(character: "BETA", lineCount: 8)]
    XCTAssertEqual(receiver.merging(discovered).map(\.lineCount), [3, 8])
  }

  /// Every other field stays fill-if-nil while `lineCount` is replaced.
  func testEveryOtherFieldStaysFillIfNil() throws {
    var mine = CastMember(
      character: "ALPHA", role: .lead, actor: "Mine", gender: .female, language: "en",
      voicePrompt: "Mine", voices: ["voxalta": ["mine.vox"]], manifest: "mine.json",
      displayName: "Mine", lineCount: 12)
    mine.setExtra(try AnyCodable("mine"), forKey: "bio")
    var theirs = CastMember(
      character: "ALPHA", role: .guest, actor: "Theirs", gender: .male, language: "fr",
      voicePrompt: "Theirs", voices: ["voxalta": ["theirs.vox"], "apple": ["a"]],
      manifest: "theirs.json", displayName: "Theirs", lineCount: 40)
    theirs.setExtra(try AnyCodable("theirs"), forKey: "bio")
    theirs.setExtra(try AnyCodable("new"), forKey: "note")

    let merged = try XCTUnwrap([mine].merging([theirs]).first)
    var expected = mine
    expected.lineCount = 40
    expected.voices["apple"] = ["a"]
    expected.setExtra(try AnyCodable("new"), forKey: "note")
    XCTAssertEqual(merged, expected)
  }
}
