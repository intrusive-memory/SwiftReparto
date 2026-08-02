// MergeTests.swift
// SwiftRepartoTests
//
// Sortie 11: tests for `[CastMember].merging(_:)` (RQ-14).
//
// A plain `import SwiftReparto`, never `@testable import`: `merging(_:)` is a
// public API, and every field it touches (`extraKeys` in particular) must be
// reachable through the same door a real consumer has (D-8), exactly like
// `CastMemberPublicAPITests.swift`.
//
// Supervisor directive A resolved this file's central ambiguity: on a match,
// the receiver's member is **gap-filled**, not passed through untouched. A
// field the receiver already has is never overwritten; a field it lacks, but
// the matched `discovered` member has, is filled in. Several tests below
// assert that distinction explicitly so a later sortie does not have to
// re-derive it from behavior.

import Foundation
import SwiftReparto
import XCTest

final class MergeTests: XCTestCase {

  // MARK: - Helpers

  private func member(
    _ character: String,
    actor: String? = nil,
    gender: Gender? = nil,
    language: String? = nil,
    voicePrompt: String? = nil,
    voices: [String: [String]] = [:],
    extras: [String: AnyCodable] = [:]
  ) -> CastMember {
    CastMember(
      character: character,
      actor: actor,
      gender: gender,
      language: language,
      voicePrompt: voicePrompt,
      voices: voices,
      extraKeys: extras
    )
  }

  // MARK: - Additive append

  func testUnmatchedDiscoveredMembersAreAppendedInOrder() {
    let receiver = [member("NARRATOR"), member("THE PRACTITIONER")]
    let discovered = [member("DOCTOR"), member("NURSE")]

    let result = receiver.merging(discovered)

    XCTAssertEqual(result.map(\.character), ["NARRATOR", "THE PRACTITIONER", "DOCTOR", "NURSE"])
  }

  // MARK: - No overwrite of an existing field

  func testExistingBioIsNotOverwrittenByAMatchWithoutOne() throws {
    let bio = try AnyCodable("Neurodivergent, gay Gen X developer in his late forties.")
    let receiver = [member("THE PRACTITIONER", extras: ["bio": bio])]
    let discovered = [member("THE PRACTITIONER")]

    let result = receiver.merging(discovered)

    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(try result[0][extra: "bio"]?.decode(String.self), try bio.decode(String.self))
  }

  func testExistingVoicePromptIsNotOverwritten() {
    let receiver = [member("NARRATOR", voicePrompt: "Deep authoritative British baritone.")]
    let discovered = [member("NARRATOR", voicePrompt: "Something else entirely.")]

    let result = receiver.merging(discovered)

    XCTAssertEqual(result[0].voicePrompt, "Deep authoritative British baritone.")
  }

  func testExistingVoicesProviderIsNotOverwrittenEvenWithDifferentPaths() {
    let receiver = [member("NARRATOR", voices: ["voxalta": ["voices/NARRATOR.vox"]])]
    let discovered = [member("NARRATOR", voices: ["voxalta": ["voices/DIFFERENT.vox"]])]

    let result = receiver.merging(discovered)

    XCTAssertEqual(result[0].voices["voxalta"], ["voices/NARRATOR.vox"])
  }

  func testExistingExtraKeyIsNotOverwritten() throws {
    let receiver = [member("NARRATOR", extras: ["bio": try AnyCodable("Original.")])]
    let discovered = [member("NARRATOR", extras: ["bio": try AnyCodable("Replacement.")])]

    let result = receiver.merging(discovered)

    XCTAssertEqual(try result[0][extra: "bio"]?.decode(String.self), "Original.")
  }

  // MARK: - Gap-filling (directive A)

  func testMissingScalarFieldsAreFilledFromDiscovered() {
    let receiver = [member("NARRATOR")]
    let discovered = [
      member(
        "NARRATOR",
        actor: "Tom Stovall",
        gender: .male,
        language: "en",
        voicePrompt: "Deep authoritative British baritone."
      )
    ]

    let result = receiver.merging(discovered)

    XCTAssertEqual(result[0].actor, "Tom Stovall")
    XCTAssertEqual(result[0].gender, .male)
    XCTAssertEqual(result[0].language, "en")
    XCTAssertEqual(result[0].voicePrompt, "Deep authoritative British baritone.")
  }

  func testNewVoicesProviderIsAddedWithoutTouchingExistingOnes() {
    let receiver = [member("NARRATOR", voices: ["voxalta": ["voices/NARRATOR.vox"]])]
    let discovered = [
      member(
        "NARRATOR",
        voices: [
          "voxalta": ["voices/DIFFERENT.vox"],
          "elevenlabs": ["voices/NARRATOR.elevenlabs"],
        ])
    ]

    let result = receiver.merging(discovered)

    XCTAssertEqual(result[0].voices["voxalta"], ["voices/NARRATOR.vox"])
    XCTAssertEqual(result[0].voices["elevenlabs"], ["voices/NARRATOR.elevenlabs"])
  }

  func testMissingExtraKeyIsFilledFromDiscovered() throws {
    let receiver = [member("NARRATOR")]
    let discovered = [member("NARRATOR", extras: ["bio": try AnyCodable("Filled in.")])]

    let result = receiver.merging(discovered)

    XCTAssertEqual(try result[0][extra: "bio"]?.decode(String.self), "Filled in.")
  }

  // MARK: - Case-insensitive match

  func testCaseInsensitiveMatchMergesToOneMember() {
    let receiver = [member("narrator")]
    let discovered = [member("NARRATOR", actor: "Tom Stovall")]

    let result = receiver.merging(discovered)

    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(result[0].actor, "Tom Stovall")
  }

  // MARK: - Whitespace-insensitive match

  func testWhitespaceInsensitiveMatchMergesToOneMember() {
    // Two spaces in the receiver, one space in `discovered`.
    let receiver = [member("THE  PRACTITIONER")]
    let discovered = [member("THE PRACTITIONER", actor: "Someone")]

    let result = receiver.merging(discovered)

    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(result[0].actor, "Someone")
  }

  func testTabsAndLeadingTrailingWhitespaceMatch() {
    let receiver = [member("\tTHE PRACTITIONER  ")]
    let discovered = [member("The Practitioner", actor: "Someone")]

    let result = receiver.merging(discovered)

    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(result[0].actor, "Someone")
  }

  // MARK: - Stored `character` is never rewritten (directive C)

  func testMatchedMemberKeepsReceiversExactCharacterSpelling() {
    let receiver = [member("THE  PRACTITIONER")]
    let discovered = [member("the practitioner", actor: "Someone")]

    let result = receiver.merging(discovered)

    XCTAssertEqual(result.count, 1)
    // The receiver's original, irregular spacing survives byte for byte —
    // normalization is for matching only and never leaks into stored data.
    XCTAssertEqual(result[0].character, "THE  PRACTITIONER")
  }

  func testAppendedMemberKeepsDiscoveredsExactCharacterSpelling() {
    let receiver: [CastMember] = []
    let discovered = [member("  THE  NEW GUY  ")]

    let result = receiver.merging(discovered)

    XCTAssertEqual(result.count, 1)
    XCTAssertEqual(result[0].character, "  THE  NEW GUY  ")
  }

  // MARK: - Empty `discovered`

  func testMergeWithEmptyDiscoveredReturnsReceiverUnchanged() throws {
    let receiver = [
      member(
        "NARRATOR",
        actor: "Tom Stovall",
        gender: .male,
        language: "en",
        voicePrompt: "Deep authoritative British baritone.",
        voices: ["voxalta": ["voices/NARRATOR.vox"]],
        extras: ["bio": try AnyCodable("Some bio.")]
      ),
      member("THE PRACTITIONER"),
    ]

    let result = receiver.merging([])

    XCTAssertEqual(result, receiver)
    XCTAssertEqual(result.count, receiver.count)
    XCTAssertEqual(result[0].voices, receiver[0].voices)
    XCTAssertEqual(result[0].extraKeys, receiver[0].extraKeys)
  }

  // MARK: - Twelve-against-one (acceptance criterion 7)

  func testTwelveMemberRosterAgainstOneMemberDiscoveredStaysAtTwelve() {
    let receiver = (1...12).map { member("CHARACTER \($0)") }
    let discovered = [member("CHARACTER 1", actor: "Newly discovered actor")]

    let result = receiver.merging(discovered)

    XCTAssertEqual(result.count, 12)
    XCTAssertEqual(result[0].actor, "Newly discovered actor")
  }

  // MARK: - Never reduces the count

  func testCountNeverShrinksWithEmptyDiscovered() {
    let receiver = [member("A"), member("B"), member("C")]
    let result = receiver.merging([])
    XCTAssertGreaterThanOrEqual(result.count, receiver.count)
    XCTAssertEqual(result.count, receiver.count)
  }

  func testCountNeverShrinksWithFullOverlap() {
    let receiver = [member("A"), member("B"), member("C")]
    let discovered = [member("a"), member("b"), member("c")]
    let result = receiver.merging(discovered)
    XCTAssertGreaterThanOrEqual(result.count, receiver.count)
    XCTAssertEqual(result.count, receiver.count)
  }

  func testCountNeverShrinksWithPartialOverlap() {
    let receiver = [member("A"), member("B"), member("C")]
    let discovered = [member("B"), member("D"), member("E")]
    let result = receiver.merging(discovered)
    XCTAssertGreaterThanOrEqual(result.count, receiver.count)
    XCTAssertEqual(result.count, 5)
    XCTAssertEqual(result.map(\.character), ["A", "B", "C", "D", "E"])
  }
}
