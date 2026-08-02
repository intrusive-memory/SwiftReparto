// CastMemberPublicAPITests.swift
// SwiftRepartoTests
//
// This file exists for one reason, and the reason is the import line at the
// top of it: a plain `import SwiftReparto`, never `@testable import`.
//
// D-8 makes `extraKeys` `public private(set)` and routes access through named
// accessors precisely so a consumer — SwiftSemblanzas reading `bio`, anything
// reading the deferred `appearance` block (D-3) — can reach preserved keys
// across a module boundary. Acceptance criterion 3 asserts `bio` preservation
// from a separate module, and reaching it through a testing-only door would
// make that acceptance test pass through an entrance consumers do not have.
//
// Every assertion below therefore goes through the same public surface a real
// dependent package sees. If any of it stops compiling, the public API has
// regressed even if the rest of the suite is green — so keep this file's
// import plain, and do not move these assertions into a `@testable` file.

import Foundation
import SwiftReparto
import XCTest

final class CastMemberPublicAPITests: XCTestCase {

  // MARK: - Reading through the public door (D-8)

  func testExtraKeysIsReadableWithoutTestableImport() throws {
    let member = try JSONDecoder().decode(
      CastMember.self,
      from: Data(
        """
        {
          "character": "THE PRACTITIONER",
          "bio": "Neurodivergent, gay Gen X developer in his late forties.",
          "appearance": {"triggerWord": "prctnr_v1"}
        }
        """.utf8
      )
    )

    // The dictionary itself is readable.
    XCTAssertEqual(member.extraKeys.count, 2)
    XCTAssertEqual(Set(member.extraKeys.keys), ["bio", "appearance"])

    // And so is the named read accessor.
    XCTAssertEqual(
      try member[extra: "bio"]?.decode(String.self),
      "Neurodivergent, gay Gen X developer in his late forties."
    )
    XCTAssertEqual(
      try member[extra: "appearance"]?.decode([String: String].self),
      ["triggerWord": "prctnr_v1"]
    )

    // An absent key reads as nil rather than trapping.
    XCTAssertNil(member[extra: "nothing-here"])
  }

  // MARK: - Writing through the public door (D-8)

  func testSetExtraIsWritableWithoutTestableImport() throws {
    var member = CastMember(character: "NARRATOR")
    XCTAssertTrue(member.extraKeys.isEmpty)

    try member.setExtra(AnyCodable("A late addition."), forKey: "bio")
    XCTAssertEqual(try member[extra: "bio"]?.decode(String.self), "A late addition.")

    // Overwriting one key leaves the others alone — the whole point of a
    // per-key writer rather than a settable dictionary.
    try member.setExtra(AnyCodable(["triggerWord": "nrrtr_v2"]), forKey: "appearance")
    try member.setExtra(AnyCodable("A revised addition."), forKey: "bio")
    XCTAssertEqual(try member[extra: "bio"]?.decode(String.self), "A revised addition.")
    XCTAssertEqual(
      try member[extra: "appearance"]?.decode([String: String].self),
      ["triggerWord": "nrrtr_v2"]
    )

    // Passing nil removes the key entirely.
    member.setExtra(nil, forKey: "bio")
    XCTAssertNil(member[extra: "bio"])
    XCTAssertEqual(Set(member.extraKeys.keys), ["appearance"])
  }

  func testExtrasWrittenThroughSetExtraSurviveAnEncodeDecodeCycle() throws {
    var member = CastMember(character: "NARRATOR", voicePrompt: "Warm, commanding.")
    try member.setExtra(AnyCodable("Unseen, omniscient, faintly amused."), forKey: "bio")

    let encoded = try JSONEncoder().encode(member)
    let decoded = try JSONDecoder().decode(CastMember.self, from: encoded)

    XCTAssertEqual(decoded[extra: "bio"], member[extra: "bio"])
    XCTAssertEqual(decoded.voicePrompt, "Warm, commanding.")
  }
}
