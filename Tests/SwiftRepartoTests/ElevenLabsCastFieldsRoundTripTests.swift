// ElevenLabsCastFieldsRoundTripTests.swift
// SwiftRepartoTests
//
// OPERATION RATIONED MEGAPHONE, Sortie 7: the EL-3.4 round-trip gate for the
// ElevenLabs cast fields.
//
// `voices` is `[String: [String]]`, so a provider key is a lower-cased name and
// each value is an ordered list of pointers. `voiceSettings` is not declared on
// `CastMember`; it is an undeclared key, swept into `extraKeys` and re-emitted
// verbatim. Both must survive parse -> write -> parse. The comparison is on
// parsed values, not bytes: undeclared keys re-emit sorted, not byte-identical.

import Foundation
import SwiftReparto
import XCTest

final class ElevenLabsCastFieldsRoundTripTests: XCTestCase {

  private let parser = CastMarkdownParser()

  private var temporaryDirectories: [URL] = []

  override func tearDownWithError() throws {
    for directory in temporaryDirectories {
      try? FileManager.default.removeItem(at: directory)
    }
    temporaryDirectories.removeAll()
    try super.tearDownWithError()
  }

  private func makeTemporaryDirectory() throws -> URL {
    let directory = URL.temporaryDirectory.appending(
      path: "SwiftRepartoElevenLabs-\(UUID().uuidString)",
      directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    temporaryDirectories.append(directory)
    return directory
  }

  /// The `voiceSettings.elevenlabs` map as a typed value, for asserting the
  /// nested structure without relying on the raw encoding.
  ///
  /// The numeric fields are `String`, not `Double`, on purpose. `YAMLCoding.swift`
  /// keeps every float-shaped plain scalar as its source spelling (`0.5` is the
  /// string `"0.5"`), because no float spelling survives `AnyCodable`'s
  /// emission path. The spelling round-trips exactly; a consumer that needs a
  /// number converts it.
  private struct ElevenLabsSettings: Codable, Equatable {
    let model: String
    let stability: String
    let similarityBoost: String

    enum CodingKeys: String, CodingKey {
      case model
      case stability
      case similarityBoost = "similarity_boost"
    }
  }

  private func loadFixture() throws -> CastDocument {
    try parser.parse(fileURL: try TestFixture.elevenLabsVoicesCastMD.url())
  }

  /// Writes `document` to a fresh `CAST.md` and parses it back.
  private func writeAndReparse(_ document: CastDocument) throws -> CastDocument {
    let directory = try makeTemporaryDirectory()
    let fileURL = directory.appending(path: "CAST.md")
    try parser.write(document: document, to: fileURL)
    return try parser.parse(fileURL: fileURL)
  }

  // MARK: - Fixture sanity

  func testFixtureDeclaresBothEL31VoiceReferenceForms() throws {
    let document = try loadFixture()

    XCTAssertEqual(document.cast.map(\.character), ["NARRATOR", "SIDEKICK"])
    XCTAssertEqual(
      document.cast[0].voices,
      [
        "voxalta": ["voices/NARRATOR.vox"],
        "elevenlabs": ["characters/NARRATOR.dossier/voice/NARRATOR.vox"],
      ])
    XCTAssertEqual(document.cast[1].voices, ["elevenlabs": ["21m00Tcm4TlvDq8ikWAM"]])
  }

  // MARK: - parse -> write -> parse

  func testParseWriteParsePreservesEveryMembersVoices() throws {
    let original = try loadFixture()
    let reparsed = try writeAndReparse(original)

    XCTAssertEqual(reparsed.cast.count, original.cast.count)
    for (before, after) in zip(original.cast, reparsed.cast) {
      XCTAssertEqual(after.character, before.character)
      XCTAssertEqual(after.voices, before.voices, "voices drifted for \(before.character)")
    }
  }

  func testParseWriteParsePreservesNestedVoiceSettingsExactly() throws {
    let original = try loadFixture()
    let reparsed = try writeAndReparse(original)

    let originalSettings = try XCTUnwrap(original.cast[0][extra: "voiceSettings"])
    let reparsedSettings = try XCTUnwrap(reparsed.cast[0][extra: "voiceSettings"])

    // Typed view: the nested map decodes to the exact values in the fixture.
    let settings = try reparsedSettings.decode([String: ElevenLabsSettings].self)
    XCTAssertEqual(
      settings,
      [
        "elevenlabs": ElevenLabsSettings(
          model: "eleven_v4", stability: "0.5", similarityBoost: "0.75")
      ])

    // Whole-value view: the nested structure is equal to what was parsed.
    XCTAssertEqual(reparsedSettings, originalSettings)
    XCTAssertEqual(reparsed.cast[0][extra: "provider"], original.cast[0][extra: "provider"])
  }

  func testParseWriteParseLeavesWholeMembersEqual() throws {
    let original = try loadFixture()
    let reparsed = try writeAndReparse(original)

    XCTAssertEqual(reparsed.cast, original.cast)
  }

  // MARK: - Editing one member leaves the others equal

  func testEditingOneMembersVoxaltaPathLeavesOtherMemberEqual() throws {
    let original = try loadFixture()

    var edited = original
    edited.cast[0].voices["voxalta"] = ["voices/NARRATOR-v2.vox"]
    let reparsed = try writeAndReparse(edited)

    XCTAssertEqual(reparsed.cast[0].voices["voxalta"], ["voices/NARRATOR-v2.vox"])
    XCTAssertEqual(
      reparsed.cast[0].voices["elevenlabs"],
      ["characters/NARRATOR.dossier/voice/NARRATOR.vox"],
      "the edited member's other providers must survive the edit")
    XCTAssertEqual(
      reparsed.cast[0][extra: "voiceSettings"], original.cast[0][extra: "voiceSettings"],
      "the edited member's nested voiceSettings must survive the edit")

    XCTAssertEqual(reparsed.cast[1], original.cast[1], "the untouched member must stay equal")
  }
}
