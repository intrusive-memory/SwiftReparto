// FixtureIntegrityTests.swift
// SwiftRepartoTests
//
// Sortie 13: WU-4's fixtures are the SHA-256 anchors every later acceptance
// gate hashes against, so this file proves the anchors themselves are sound
// before Sortie 14 builds gates on top of them.
//
// A plain `import SwiftReparto`, matching the rest of this suite: nothing
// here needs `@testable import`.
//
// Every fixture is reached through `TestFixture` (`Bundle.module`), never by
// a path spelled in this file — see `TestFixture.swift`.

import CryptoKit
import Foundation
import SwiftReparto
import XCTest

final class FixtureIntegrityTests: XCTestCase {

  private let parser = CastMarkdownParser()

  private func sha256(_ string: String) -> String {
    SHA256.hash(data: Data(string.utf8)).map { String(format: "%02x", $0) }.joined()
  }

  // MARK: - Every fixture loads through Bundle.module

  func testConfessionsProjectFixtureImportsWithoutThrowing() throws {
    let url = try TestFixture.confessionsProjectMD.url()
    XCTAssertNoThrow(try ProjectCastImporter().importCast(fileURL: url))
  }

  func testConfessionsCastFixtureParsesWithoutThrowing() throws {
    let url = try TestFixture.confessionsCastMD.url()
    XCTAssertNoThrow(try parser.parse(fileURL: url))
  }

  func testAllFieldsCastFixtureParsesWithoutThrowing() throws {
    let url = try TestFixture.allFieldsCastMD.url()
    XCTAssertNoThrow(try parser.parse(fileURL: url))
  }

  func testLegacyUnversionedCastFixtureParsesWithoutThrowing() throws {
    let url = try TestFixture.legacyUnversionedCastMD.url()
    let document = try parser.parse(fileURL: url)

    // D-5's legacy path: no `schemaVersion` key at all is legacy, not invalid.
    XCTAssertTrue(document.isUnversioned)
    XCTAssertEqual(document.cast.map(\.character), ["NARRATOR", "SIDEKICK"])
  }

  // MARK: - RQ-11: `confessions-CAST.md` is already in emitted form

  /// Sortie 13's own exit criterion: this fixture is the RQ-11 SHA-256 anchor,
  /// so it must already agree with what the library would emit. Sortie 14
  /// asserts this more thoroughly; this is the standing proof the fixture
  /// itself is sound.
  func testConfessionsCastFixtureRoundTripsByteForByte() throws {
    let original = try TestFixture.confessionsCastMD.contents()
    let regenerated = try parser.generate(document: try parser.parse(content: original))

    XCTAssertEqual(sha256(regenerated), sha256(original))
    XCTAssertEqual(Array(regenerated.utf8), Array(original.utf8))
  }

  // MARK: - D-3: `all-fields-CAST.md`'s nested `appearance:` block round-trips

  /// The direct proof that D-3's deferral of `Appearance` costs no data:
  /// `appearance` is not a declared key, so it rides through `extraKeys`
  /// verbatim, and the whole document — nested block included — is a byte
  /// fixed point.
  func testAllFieldsCastFixtureRoundTripsByteForByteIncludingAppearanceBlock() throws {
    let original = try TestFixture.allFieldsCastMD.contents()
    XCTAssertTrue(original.contains("appearance:"), "fixture must exercise D-3's deferral")

    let parsed = try parser.parse(content: original)
    let regenerated = try parser.generate(document: parsed)

    XCTAssertEqual(sha256(regenerated), sha256(original))
    XCTAssertEqual(Array(regenerated.utf8), Array(original.utf8))

    // And the block itself survived, reachable the same way any consumer
    // reaches an undeclared key (D-8) — not merely present in the raw bytes.
    let oracle = try XCTUnwrap(parsed.cast.first { $0.character == "THE ORACLE" })
    let appearance = try XCTUnwrap(oracle[extra: "appearance"])
    let nested = try appearance.decode([String: AnyCodable].self)
    XCTAssertEqual(try nested["lora"]?.decode(String.self), "loras/oracle.safetensors")
    XCTAssertEqual(try nested["loraRank"]?.decode(Int.self), 16)
  }

  // MARK: - `grep -c 'struct Appearance' Sources/` returns 0 (D-3)

  /// Not a source grep — that lives in the exit-criteria report — but the
  /// behavioral half of the same guarantee: nothing about parsing or
  /// generating this fixture requires a typed `Appearance`.
  func testAllFieldsCastFixtureDoesNotRequireATypedAppearance() throws {
    let document = try parser.parse(content: try TestFixture.allFieldsCastMD.contents())
    let oracle = try XCTUnwrap(document.cast.first { $0.character == "THE ORACLE" })
    XCTAssertNotNil(oracle[extra: "appearance"])
  }
}
