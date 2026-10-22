// CanonicalNameTests.swift
// SwiftRepartoTests
//
// RQ-22: `CastMember.canonicalName(_:)`, the canonical match key in
// `merging(_:)`, and the RQ-24 merge rules for `role` / `manifest`.
// Acceptance criteria 6 and 7. Synthetic data only.

import Foundation
import SwiftReparto
import XCTest

final class CanonicalNameTests: XCTestCase {

  // MARK: - Acceptance 6: table test

  func testCanonicalNameTable() throws {
    let table: [(String, String)] = [
      // RQ-22's own examples.
      ("NARRATOR (V.O.)", "NARRATOR"),
      ("@McCLANE", "MCCLANE"),
      ("dr. o'neill", "DR. O'NEILL"),
      ("GUARD #2", "GUARD #2"),
      ("JOSÉ", "JOSÉ"),
      // Every named cue extension, and any other trailing parenthetical.
      ("NARRATOR (O.S.)", "NARRATOR"),
      ("NARRATOR (O.C.)", "NARRATOR"),
      ("NARRATOR (CONT'D)", "NARRATOR"),
      ("NARRATOR (ON PHONE)", "NARRATOR"),
      ("NARRATOR (V.O.) (CONT'D)", "NARRATOR"),
      ("NARRATOR(V.O.)", "NARRATOR"),
      ("NARRATOR (V.O.)   ", "NARRATOR"),
      ("NARRATOR (A (B))", "NARRATOR"),
      ("@NARRATOR (V.O.)", "NARRATOR"),
      ("  @ narrator", "NARRATOR"),
      // Only a *trailing* parenthetical is a cue extension.
      ("THE (OLD) MAN", "THE (OLD) MAN"),
      ("GUARD)", "GUARD)"),
      // Whitespace.
      ("  THE   PRACTITIONER\t", "THE PRACTITIONER"),
      ("THE\u{00A0}PRACTITIONER", "THE PRACTITIONER"),
      ("THE\nPRACTITIONER", "THE PRACTITIONER"),
      // Case, locale-independent: `i` never becomes a dotted capital.
      ("josé", "JOSÉ"),
      ("ingrid", "INGRID"),
      // NFC: a decomposed é composes.
      ("JOSE\u{0301}", "JOS\u{00C9}"),
      ("jose\u{0301} (V.O.)", "JOS\u{00C9}"),
      // Not leading: a dot later is fine.
      ("MR. SMITH", "MR. SMITH"),
    ]
    for (raw, expected) in table {
      XCTAssertEqual(
        try CastMember.canonicalName(raw), expected, "canonicalName(\(raw.debugDescription))")
    }
  }

  func testCanonicalOutputIsNFC() throws {
    let output = try CastMember.canonicalName("jose\u{0301}")
    XCTAssertEqual(Array(output.unicodeScalars), Array("JOS\u{00C9}".unicodeScalars))
  }

  func testCanonicalNameThrowingCases() {
    let table: [(String, CharacterNameError)] = [
      ("", .empty(raw: "")),
      ("   ", .empty(raw: "   ")),
      ("(V.O.)", .empty(raw: "(V.O.)")),
      ("@", .empty(raw: "@")),
      ("@ (CONT'D)", .empty(raw: "@ (CONT'D)")),
      ("AC/DC", .forbiddenCharacter(raw: "AC/DC", character: "/")),
      ("NOTE: ME", .forbiddenCharacter(raw: "NOTE: ME", character: ":")),
      (".HIDDEN", .leadingDot(raw: ".HIDDEN")),
      ("@.HIDDEN", .leadingDot(raw: "@.HIDDEN")),
      ("  .hidden (V.O.)", .leadingDot(raw: "  .hidden (V.O.)")),
    ]
    for (raw, expected) in table {
      XCTAssertThrowsError(
        try CastMember.canonicalName(raw), "canonicalName(\(raw.debugDescription))"
      ) { error in
        XCTAssertEqual(error as? CharacterNameError, expected, raw.debugDescription)
      }
    }
  }

  func testCharacterNameErrorsHaveDistinctDescriptions() {
    let errors: [CharacterNameError] = [
      .empty(raw: "x"), .forbiddenCharacter(raw: "x", character: "/"), .leadingDot(raw: "x"),
    ]
    let descriptions = errors.compactMap(\.errorDescription)
    XCTAssertEqual(Set(descriptions).count, errors.count)
  }

  func testCanonicalNameIsIdempotent() throws {
    for raw in ["NARRATOR (V.O.)", "@McCLANE", "dr. o'neill", "GUARD #2", "JOSE\u{0301}"] {
      let once = try CastMember.canonicalName(raw)
      XCTAssertEqual(try CastMember.canonicalName(once), once)
    }
  }

  /// No character is ever substituted: only decorations, whitespace, and case
  /// change.
  func testCanonicalNameNeverSubstitutesCharacters() throws {
    XCTAssertEqual(try CastMember.canonicalName("O'BRIEN-SMITH #3!"), "O'BRIEN-SMITH #3!")
  }

  func testHasCanonicalName() {
    XCTAssertTrue(CastMember(character: "NARRATOR").hasCanonicalName)
    XCTAssertFalse(CastMember(character: "Narrator").hasCanonicalName)
    XCTAssertFalse(CastMember(character: "NARRATOR (V.O.)").hasCanonicalName)
    XCTAssertFalse(CastMember(character: "AC/DC").hasCanonicalName)
  }

  /// RQ-INV-4: decoding never rewrites `character`.
  func testDecodingKeepsCharacterExactlyAsWritten() throws {
    let document = try CastMarkdownParser().parse(
      content: """
        ---
        type: cast
        cast:
        - character: narrator (V.O.)
        ---

        """)
    XCTAssertEqual(document.cast.first?.character, "narrator (V.O.)")
  }

  // MARK: - Acceptance 7: matching uses the canonical form

  func testCueExtensionMergesIntoTheBareName() {
    let existing = [CastMember(character: "NARRATOR", actor: "A. Person")]
    let merged = existing.merging([
      CastMember(character: "NARRATOR (V.O.)", voicePrompt: "Low and even.")
    ])
    XCTAssertEqual(merged.count, 1, "backfills, does not append")
    XCTAssertEqual(merged[0].character, "NARRATOR")
    XCTAssertEqual(merged[0].actor, "A. Person")
    XCTAssertEqual(merged[0].voicePrompt, "Low and even.")
  }

  func testForceMarkerAndCaseMerge() {
    let merged = [CastMember(character: "MCCLANE")].merging([
      CastMember(character: "@McClane", language: "en")
    ])
    XCTAssertEqual(merged.count, 1)
    XCTAssertEqual(merged[0].character, "MCCLANE")
    XCTAssertEqual(merged[0].language, "en")
  }

  func testComposedAndDecomposedNamesMerge() {
    let merged = [CastMember(character: "JOS\u{00C9}")].merging([
      CastMember(character: "JOSE\u{0301}", actor: "A. Person")
    ])
    XCTAssertEqual(merged.count, 1)
    XCTAssertEqual(merged[0].actor, "A. Person")
  }

  /// A receiver whose own spelling is not canonical still matches, and keeps
  /// its spelling (RQ-INV-4).
  func testNonCanonicalReceiverKeepsItsSpelling() {
    let merged = [CastMember(character: "Narrator (V.O.)")].merging([
      CastMember(character: "NARRATOR", actor: "A. Person")
    ])
    XCTAssertEqual(merged.map(\.character), ["Narrator (V.O.)"])
    XCTAssertEqual(merged[0].actor, "A. Person")
  }

  /// A name with no canonical form falls back to the 0.1.0 key and still
  /// matches case- and whitespace-insensitively.
  func testUncanonicalizableNamesFallBackToTheLegacyKey() {
    let merged = [CastMember(character: "AC/DC")].merging([
      CastMember(character: "  ac/dc ", actor: "A. Person"),
      CastMember(character: "AC DC"),
    ])
    XCTAssertEqual(merged.map(\.character), ["AC/DC", "AC DC"])
    XCTAssertEqual(merged[0].actor, "A. Person")
  }

  func testDistinctCanonicalNamesStayDistinct() {
    let merged = [CastMember(character: "GUARD #1")].merging([
      CastMember(character: "GUARD #2"), CastMember(character: "GUARD"),
    ])
    XCTAssertEqual(merged.map(\.character), ["GUARD #1", "GUARD #2", "GUARD"])
  }

  // MARK: - RQ-24: role / manifest merge rules

  func testRoleAndManifestAreFilledWhenNil() {
    let merged = [CastMember(character: "NARRATOR")].merging([
      CastMember(
        character: "NARRATOR", role: .narrator,
        manifest: "characters/NARRATOR.dossier/manifest.json")
    ])
    XCTAssertEqual(merged[0].role, .narrator)
    XCTAssertEqual(merged[0].manifest, "characters/NARRATOR.dossier/manifest.json")
  }

  func testExistingRoleAndManifestAreNeverOverwritten() {
    let merged = [
      CastMember(character: "NARRATOR", role: .lead, manifest: "keep/manifest.json")
    ].merging([
      CastMember(character: "NARRATOR (V.O.)", role: .narrator, manifest: "other/manifest.json")
    ])
    XCTAssertEqual(merged[0].role, .lead)
    XCTAssertEqual(merged[0].manifest, "keep/manifest.json")
  }

  func testUnmatchedMemberIsAppendedWithItsRoleAndManifest() {
    let discovered = CastMember(
      character: "COURIER", role: .supporting, manifest: "characters/COURIER/manifest.json")
    let merged = [CastMember(character: "NARRATOR")].merging([discovered])
    XCTAssertEqual(merged.last, discovered)
  }
}
