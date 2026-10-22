// CastMemberCodingTests.swift
// SwiftRepartoTests
//
// Sortie 6 coding tests for `CastMember`. Every case here is a decode/encode
// assertion against the field table in REQUIREMENTS.md §3.2 and the leniency
// rules in RQ-3/RQ-4.
//
// These tests deliberately go through `JSONEncoder`/`JSONDecoder` rather than
// YAML. The YAML layer is Sortie 8's, and asserting model semantics through an
// encoder this sortie does not own would make a model bug and a YAML bug look
// identical. `AnyCodable` canonicalizes through JSON internally, so an
// `AnyCodable == AnyCodable` comparison here is a byte comparison of the
// preserved value.
//
// This file uses `@testable import` so the distinction from
// `CastMemberPublicAPITests.swift` — which uses a plain `import SwiftReparto`
// to prove `extraKeys` is reachable through the door a real consumer has
// (D-8) — is structural rather than incidental.

import Foundation
import XCTest

@testable import SwiftReparto

final class CastMemberCodingTests: XCTestCase {

  // MARK: - Helpers

  private func decodeMember(_ json: String) throws -> CastMember {
    try JSONDecoder().decode(CastMember.self, from: Data(json.utf8))
  }

  private func encodeMemberAsObject(_ member: CastMember) throws -> [String: Any] {
    let data = try JSONEncoder().encode(member)
    return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
  }

  // MARK: - RQ-3: `voicePrompt` and its legacy alias

  func testVoicePromptDecodes() throws {
    let member = try decodeMember(
      """
      {"character": "NARRATOR", "voicePrompt": "Deep authoritative British baritone."}
      """
    )

    XCTAssertEqual(member.character, "NARRATOR")
    XCTAssertEqual(member.voicePrompt, "Deep authoritative British baritone.")
    XCTAssertTrue(member.extraKeys.isEmpty)
  }

  func testLegacyVoiceDescriptionKeyDecodesIntoVoicePrompt() throws {
    let member = try decodeMember(
      """
      {"character": "NARRATOR", "voiceDescription": "Legacy prose from an older writer."}
      """
    )

    XCTAssertEqual(member.voicePrompt, "Legacy prose from an older writer.")

    // The legacy key is a declared wire key, so it must not also be swept into
    // the undeclared-key store — otherwise it would be re-emitted alongside
    // `voicePrompt` and the document would carry the value twice.
    XCTAssertNil(member[extra: "voiceDescription"])
    XCTAssertTrue(member.extraKeys.isEmpty)
  }

  func testVoicePromptWinsWhenBothKeysArePresent() throws {
    let member = try decodeMember(
      """
      {
        "character": "NARRATOR",
        "voicePrompt": "Preferred.",
        "voiceDescription": "Legacy."
      }
      """
    )

    XCTAssertEqual(member.voicePrompt, "Preferred.")
  }

  /// Exit criterion: a member decoded from `voiceDescription:` re-encodes with
  /// the key `voicePrompt` and no `voiceDescription` key at all.
  func testLegacyVoiceDescriptionReEncodesAsVoicePromptOnly() throws {
    let member = try decodeMember(
      """
      {"character": "NARRATOR", "voiceDescription": "Legacy prose from an older writer."}
      """
    )

    let object = try encodeMemberAsObject(member)

    XCTAssertEqual(object["voicePrompt"] as? String, "Legacy prose from an older writer.")
    XCTAssertNil(object["voiceDescription"])
  }

  /// Exit criterion: reading and writing through the deprecated shim both
  /// reach `voicePrompt` (D-2).
  ///
  /// The test method itself is marked deprecated so exercising the shim raises
  /// no diagnostic; the shim's own `@available` attribute stays exactly as
  /// declared.
  @available(
    *, deprecated,
    message: "Deliberately exercises the deprecated voiceDescription shim (D-2)."
  )
  func testDeprecatedShimReadsAndWritesVoicePrompt() throws {
    var member = CastMember(character: "NARRATOR", voicePrompt: "Original prose.")

    // Getter reaches through to the preferred property.
    XCTAssertEqual(member.voiceDescription, "Original prose.")

    // Setter reaches through in the other direction.
    member.voiceDescription = "Rewritten prose."
    XCTAssertEqual(member.voicePrompt, "Rewritten prose.")
    XCTAssertEqual(member.voiceDescription, "Rewritten prose.")

    // And what the shim wrote emits under the preferred key.
    let object = try encodeMemberAsObject(member)
    XCTAssertEqual(object["voicePrompt"] as? String, "Rewritten prose.")
    XCTAssertNil(object["voiceDescription"])
  }

  // MARK: - RQ-3: `voices` accepts scalar and array, emits array

  func testScalarVoicesValueDecodesAsOneElementArray() throws {
    let member = try decodeMember(
      """
      {"character": "THE PRACTITIONER", "voices": {"voxalta": "voices/THE_PRACTITIONER.vox"}}
      """
    )

    XCTAssertEqual(member.voices, ["voxalta": ["voices/THE_PRACTITIONER.vox"]])
  }

  func testArrayVoicesValueDecodes() throws {
    let member = try decodeMember(
      """
      {
        "character": "NARRATOR",
        "voices": {"voxalta": ["voices/NARRATOR.vox", "voices/NARRATOR-alt.vox"]}
      }
      """
    )

    XCTAssertEqual(
      member.voices,
      ["voxalta": ["voices/NARRATOR.vox", "voices/NARRATOR-alt.vox"]]
    )
  }

  /// Exit criterion: a member decoded from the scalar form re-encodes in the
  /// array form.
  func testScalarVoicesReEncodesAsArray() throws {
    let member = try decodeMember(
      """
      {"character": "THE PRACTITIONER", "voices": {"voxalta": "voices/THE_PRACTITIONER.vox"}}
      """
    )

    let object = try encodeMemberAsObject(member)
    let voices = try XCTUnwrap(object["voices"] as? [String: Any])

    XCTAssertEqual(voices["voxalta"] as? [String], ["voices/THE_PRACTITIONER.vox"])
    XCTAssertNil(voices["voxalta"] as? String)
  }

  func testVoicesAlwaysEmittedAsArrayForProgrammaticallyBuiltMembers() throws {
    let member = CastMember(
      character: "NARRATOR",
      voices: ["voxalta": ["voices/NARRATOR.vox"]]
    )

    let object = try encodeMemberAsObject(member)
    let voices = try XCTUnwrap(object["voices"] as? [String: Any])

    XCTAssertEqual(voices["voxalta"] as? [String], ["voices/NARRATOR.vox"])
  }

  // MARK: - RQ-4: undeclared keys survive verbatim

  /// Exit criterion: a member carrying `bio:` re-encodes with `bio:` present
  /// and its value byte-identical. `bio` is the live case — it exists in
  /// production data and nothing in the ecosystem declares it.
  func testUnknownBioKeyIsCapturedAndReEmittedVerbatim() throws {
    let bio = """
      Neurodivergent (ADHD), gay Gen X developer in his late forties. Speaks in \
      long qualified sentences, then undercuts them.
      """

    let member = try decodeMember(
      #"""
      {"character": "THE PRACTITIONER", "bio": "\#(bio)"}
      """#
    )

    XCTAssertEqual(try member[extra: "bio"]?.decode(String.self), bio)

    let object = try encodeMemberAsObject(member)
    XCTAssertEqual(object["bio"] as? String, bio)

    // A full decode -> encode -> decode cycle leaves the preserved value
    // byte-identical: `AnyCodable`'s equality is byte equality on its
    // canonical encoded form.
    let reencoded = try JSONEncoder().encode(member)
    let roundTripped = try JSONDecoder().decode(CastMember.self, from: reencoded)
    XCTAssertEqual(roundTripped[extra: "bio"], member[extra: "bio"])
  }

  /// Exit criterion: a member carrying a nested `appearance:` block round-trips
  /// byte-identically through `extraKeys`.
  ///
  /// Legacy data (RQ-25): `appearance` is deprecated and never declared, so a
  /// block written before 0.2.0 is swept into the undeclared-key store like
  /// any other unknown key and costs no data.
  func testNestedAppearanceBlockRoundTripsVerbatimThroughExtraKeys() throws {
    let json = """
      {
        "character": "NARRATOR",
        "appearance": {
          "portrait": "characters/narrator/source/01.png",
          "lora": "characters/narrator/lora/narrator-v2.safetensors",
          "triggerWord": "nrrtr_v2"
        }
      }
      """

    let member = try decodeMember(json)

    // Captured as an undeclared key, not dropped and not typed.
    let appearance = try XCTUnwrap(member[extra: "appearance"])
    let fields = try appearance.decode([String: String].self)
    XCTAssertEqual(fields["portrait"], "characters/narrator/source/01.png")
    XCTAssertEqual(fields["lora"], "characters/narrator/lora/narrator-v2.safetensors")
    XCTAssertEqual(fields["triggerWord"], "nrrtr_v2")

    // Re-emitted with the nested structure intact — not flattened, not
    // stringified.
    let object = try encodeMemberAsObject(member)
    let emitted = try XCTUnwrap(object["appearance"] as? [String: Any])
    XCTAssertEqual(
      emitted as NSDictionary,
      [
        "portrait": "characters/narrator/source/01.png",
        "lora": "characters/narrator/lora/narrator-v2.safetensors",
        "triggerWord": "nrrtr_v2",
      ] as NSDictionary
    )

    // Byte-identical across the full cycle.
    let reencoded = try JSONEncoder().encode(member)
    let roundTripped = try JSONDecoder().decode(CastMember.self, from: reencoded)
    XCTAssertEqual(roundTripped[extra: "appearance"], member[extra: "appearance"])
  }

  // MARK: - Declared fields

  func testEveryDeclaredFieldRoundTripsAlongsideUndeclaredOnes() throws {
    let json = """
      {
        "character": "NARRATOR",
        "actor": "Tom Stovall",
        "gender": "M",
        "language": "en",
        "voicePrompt": "Deep authoritative British baritone.",
        "voices": {"voxalta": ["voices/NARRATOR.vox"]},
        "bio": "Unseen, omniscient, faintly amused."
      }
      """

    let member = try decodeMember(json)
    XCTAssertEqual(member.character, "NARRATOR")
    XCTAssertEqual(member.actor, "Tom Stovall")
    XCTAssertEqual(member.gender, .male)
    XCTAssertEqual(member.language, "en")
    XCTAssertEqual(member.voicePrompt, "Deep authoritative British baritone.")
    XCTAssertEqual(member.voices, ["voxalta": ["voices/NARRATOR.vox"]])
    XCTAssertEqual(
      try member[extra: "bio"]?.decode(String.self),
      "Unseen, omniscient, faintly amused."
    )

    let reencoded = try JSONEncoder().encode(member)
    let roundTripped = try JSONDecoder().decode(CastMember.self, from: reencoded)
    XCTAssertEqual(roundTripped, member)
  }
}
